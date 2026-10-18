# =============================================================================
# Certificado HTTPS del curso  (ARCHIVO ENTREGADO: no hace falta modificarlo)
#
# El docente emite UN certificado comodín para *.lab.jplorier.com con
# Let's Encrypt y se lo entrega a cada grupo, en privado, como tres archivos
# que van en la carpeta certs/ del proyecto:
#   certs/lab.crt     el certificado
#   certs/lab.key     su clave privada  <- SECRETO (está en .gitignore)
#   certs/cadena.crt  el certificado intermedio de Let's Encrypt
#
# Un certificado de ACM solo lo puede usar un ALB de la MISMA cuenta de AWS:
# por eso cada grupo lo IMPORTA en la suya. Al importarlo, ACM no lo renueva
# solo: cuando el docente entrega uno nuevo, se reemplazan los archivos y se
# vuelve a aplicar (el ARN no cambia).
#
# Si faltan los archivos, no se importa nada y el ALB atiende solo por HTTP.
# =============================================================================

locals {
  dir_certs = "${path.root}/certs"

  # Los tres archivos, o null si falta alguno (try() atrapa el error de file()).
  certificado = try({
    cuerpo = file("${local.dir_certs}/lab.crt")
    clave  = file("${local.dir_certs}/lab.key")
    cadena = file("${local.dir_certs}/cadena.crt")
  }, null)
}

resource "aws_acm_certificate" "lab" {
  # Una copia si están los archivos, ninguna si no.
  for_each = local.certificado == null ? {} : { lab = local.certificado }

  certificate_body  = each.value.cuerpo
  private_key       = each.value.clave
  certificate_chain = each.value.cadena

  tags = { Name = "lab-${var.grupo}" }
}

locals {
  # hay_certificado se conoce al planificar (depende de si están los archivos);
  # el ARN, recién al aplicar. El módulo necesita los dos.
  hay_certificado = local.certificado != null
  certificado_arn = local.hay_certificado ? aws_acm_certificate.lab["lab"].arn : null
}
