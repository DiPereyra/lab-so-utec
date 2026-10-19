# Laboratorio AWS — proyecto OpenTofu

El enunciado completo está en Moodle. Este archivo es un recordatorio rápido.

## Estructura

| Ruta | Contenido | ¿Se modifica? |
|---|---|---|
| `versions.tf`, `providers.tf`, `variables.tf` | Base del proyecto | No |
| `red.tf` | VPC; mitad pública resuelta, mitad privada TODO 2.x | **Sí** |
| `servicios.tf` | Llamada al módulo y subdominio en deSEC (TODO 3.1 y 3.2) | **Sí** |
| `modulos/servicios/` | S3, ALB con reglas `/s3`, `/ecs/` y `/vm/`, ECS, IAM — terminado | No (leer) |
| `claves.tf` | Una clave SSH por instancia | No |
| `certificado.tf` | Importa en ACM el certificado HTTPS del curso (`certs/`) | No |
| `instancias.tf` | Variables, AMI, security groups, instancias, publicación en el ALB (TODO 4.x) | **Sí** |
| `outputs.tf` | Salidas; descomentar por partes | **Sí** |
| `plantillas/ssh_config.tftpl` | Plantilla del archivo de configuración SSH | No |
| `plantillas/servidor-web.sh.tftpl` | `user_data` del servidor privado: nginx + sitio en `/vm/` | No (leer) |
| `sitio/` | Sitio estático que se sube a S3 | Personalizar `index.html` |
| `scripts/` | Encender, apagar, estado, apagado automático | No |
| `openvpn/` | Kit para el bastión (ver `openvpn/LEAME.md`) | No |

## Arranque

```bash
git pull upstream main                           # traer las actualizaciones del docente
cp .env.example .env && chmod 600 .env         # completar credenciales (Parte 0)
source .env                                      # en cada terminal nueva
cp terraform.tfvars.example terraform.tfvars   # completar
aws sts get-caller-identity                      # ¿credenciales OK?
tofu init
tofu plan
```

## Trabajo en grupo y entrega

El grupo trabaja en un **fork** de `jplorier/lab-so-utec` (uno lo crea y suma a los demás como colaboradores).

```bash
git clone https://github.com/USUARIO/lab-so-utec.git && cd lab-so-utec
git remote add upstream https://github.com/jplorier/lab-so-utec.git
git pull upstream main     # traer correcciones del docente
git push                   # subir sus commits al fork
```

Entrega: **pull request** desde el fork hacia `jplorier/lab-so-utec` (`main`), título `Entrega gN - Apellidos`.
Ningún commit puede contener secretos (`.env`, `terraform.tfvars`, `certs/`, `claves/`, estado).

## Al terminar CADA jornada

```bash
tofu destroy
./scripts/estado.sh     # todo vacío
```

## Nunca entregar ni subir a git

`terraform.tfstate*`, `.terraform/`, `terraform.tfvars`, `claves/`, `*.ovpn`, claves de AWS, token de deSEC, `.env`, `certs/`.
