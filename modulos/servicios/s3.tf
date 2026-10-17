# =============================================================================
# Sitio web estático en S3
#
# S3 es almacenamiento de objetos: no hay servidor, ni sistema operativo, ni
# disco que administrar. Con "website hosting" S3 responde HTTP directamente.
#
# Los nombres de bucket son GLOBALES (únicos en todo AWS), por eso le
# agregamos un sufijo aleatorio.
# =============================================================================

resource "random_id" "sufijo" {
  byte_length = 3
}

resource "aws_s3_bucket" "sitio" {
  bucket = "${var.nombre}-sitio-${random_id.sufijo.hex}"

  # Permite que "tofu destroy" borre el bucket aunque tenga objetos adentro.
  force_destroy = true
}

# Los objetos pertenecen siempre al dueño del bucket; se desactivan las ACL.
resource "aws_s3_bucket_ownership_controls" "sitio" {
  bucket = aws_s3_bucket.sitio.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Por defecto S3 bloquea todo acceso público. Para un sitio web hay que
# permitir una POLÍTICA pública (no ACL). Ojo: si la cuenta tiene activado el
# bloqueo público a nivel de cuenta, esto no alcanza (ver "Problemas
# frecuentes" en el enunciado).
resource "aws_s3_bucket_public_access_block" "sitio" {
  bucket = aws_s3_bucket.sitio.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "sitio" {
  bucket = aws_s3_bucket.sitio.id

  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

# Política: cualquiera ("*") puede LEER (GetObject) objetos del bucket.
# No puede listar, ni escribir, ni borrar.
data "aws_iam_policy_document" "lectura_publica" {
  statement {
    sid       = "LecturaPublicaDelSitio"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.sitio.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "sitio" {
  bucket = aws_s3_bucket.sitio.id
  policy = data.aws_iam_policy_document.lectura_publica.json

  # Si la política se aplica antes de liberar el bloqueo público, AWS la rechaza.
  depends_on = [aws_s3_bucket_public_access_block.sitio]
}

# --- Subida de archivos ------------------------------------------------------

locals {
  tipos_mime = {
    html = "text/html; charset=utf-8"
    css  = "text/css; charset=utf-8"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    gif  = "image/gif"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
    txt  = "text/plain; charset=utf-8"
  }

  archivos_sitio = fileset(var.directorio_sitio, "**")

  # Huella de todo el sitio: cambia si cambia cualquier archivo.
  version_sitio = sha1(join(",", [for f in local.archivos_sitio : filemd5("${var.directorio_sitio}/${f}")]))
}

# Un objeto S3 por cada archivo de la carpeta. El etag (hash MD5) hace que
# OpenTofu vuelva a subir un archivo solo cuando cambia su contenido.
resource "aws_s3_object" "sitio" {
  for_each = local.archivos_sitio

  bucket = aws_s3_bucket.sitio.id
  key    = each.value
  source = "${var.directorio_sitio}/${each.value}"
  etag   = filemd5("${var.directorio_sitio}/${each.value}")

  content_type = lookup(
    local.tipos_mime,
    lower(reverse(split(".", each.value))[0]),
    "application/octet-stream"
  )
}
