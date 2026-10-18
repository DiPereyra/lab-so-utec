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

# El bucket se crea con la AWS CLI y no con aws_s3_bucket. Al leer un
# aws_s3_bucket, el proveedor consulta muchas configuraciones del bucket, entre
# ellas Object Lock, y AWS Academy Learner Lab lo prohíbe con una política de
# la organización (AccessDenied en GetObjectLockConfiguration). Los demás
# recursos de este archivo no hacen esa consulta.
#
# terraform_data no crea nada en AWS: guarda "input" en el estado y ejecuta
# los comandos (provisioners) al crearse y al destruirse.
resource "terraform_data" "bucket" {
  input = {
    nombre = "${var.nombre}-sitio-${random_id.sufijo.hex}"
    region = data.aws_region.actual.region
  }

  # Fuera de us-east-1, S3 exige indicar la región también como LocationConstraint.
  provisioner "local-exec" {
    command = "aws s3api create-bucket --bucket ${self.input.nombre} --region ${self.input.region}${self.input.region == "us-east-1" ? "" : " --create-bucket-configuration LocationConstraint=${self.input.region}"}"
  }

  # --force borra los objetos que queden antes de borrar el bucket.
  provisioner "local-exec" {
    when    = destroy
    command = "aws s3 rb s3://${self.input.nombre} --force --region ${self.input.region}"
  }
}

locals {
  # Usar output (y no un string armado a mano) crea la dependencia: los demás
  # recursos esperan a que el bucket exista.
  bucket     = terraform_data.bucket.output.nombre
  bucket_arn = "arn:${data.aws_partition.actual.partition}:s3:::${local.bucket}"
}

# Los objetos pertenecen siempre al dueño del bucket; se desactivan las ACL.
resource "aws_s3_bucket_ownership_controls" "sitio" {
  bucket = local.bucket
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Por defecto S3 bloquea todo acceso público. Para un sitio web hay que
# permitir una POLÍTICA pública (no ACL). Ojo: si la cuenta tiene activado el
# bloqueo público a nivel de cuenta, esto no alcanza (ver "Problemas
# frecuentes" en el enunciado).
resource "aws_s3_bucket_public_access_block" "sitio" {
  bucket = local.bucket

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "sitio" {
  bucket = local.bucket

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
    resources = ["${local.bucket_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "sitio" {
  bucket = local.bucket
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

  bucket = local.bucket
  key    = each.value
  source = "${var.directorio_sitio}/${each.value}"
  etag   = filemd5("${var.directorio_sitio}/${each.value}")

  # no-cache: el navegador puede guardar el archivo, pero antes de usarlo
  # pregunta si cambió. Sin esto, al editar el sitio se sigue viendo el CSS viejo.
  cache_control = "no-cache"

  content_type = lookup(
    local.tipos_mime,
    lower(reverse(split(".", each.value))[0]),
    "application/octet-stream"
  )
}
