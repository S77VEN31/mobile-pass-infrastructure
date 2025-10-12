# Pass Generator Infrastructure

Configuración de Nginx como reverse proxy para el proyecto Pass Generator. Esta infraestructura maneja el enrutamiento SSL/TLS para los dominios `mobilepass.itass.cloud` (frontend) y `wallet.itass.cloud` (backend).

## 🏗️ Arquitectura

### Nuevo Esquema con Virtual Server NIS
```
Internet → Virtual Server NIS → Servidor Local → Nginx → Servicios
         (Múltiples dominios)                    (Enrutamiento)
                                                  ├─→ Frontend (3000)
                                                  └─→ Backend (3001)
```

El Virtual Server NIS enruta el tráfico basado en dominio hacia el servidor local, donde Nginx actúa como reverse proxy hacia los servicios internos.

## 📋 Estructura

```
pass-generator-infrastructure/
├── docker-compose.yml               # Orquestación de servicios
├── nginx.conf                       # Configuración principal de Nginx
├── conf.d/
│   ├── pass-generator.conf          # Configuración de virtual hosts
│   ├── common-proxy-headers.conf    # Headers de proxy compartidos (DRY)
│   ├── common-ssl.conf              # Configuración SSL compartida (DRY)
│   └── common-security-headers.conf # Headers de seguridad compartidos (DRY)
├── certificates/                    # Certificados SSL
│   └── api.itass.cloud/            # Wildcard *.itass.cloud
│       ├── certificate.crt
│       └── private.key
├── verify-nginx-config.sh          # Script de verificación
├── deploy.sh                       # Script de despliegue
├── check-status.sh                 # Script de verificación de estado
├── README.md                       # Este archivo
└── NGINX-CONFIGURATION.md          # Documentación técnica detallada
```

## 🚀 Servicios

### Nginx Reverse Proxy
- **Container**: `pass-generator-nginx`
- **Puertos**: 80 (HTTP), 443 (HTTPS)
- **Funciones**:
  - Proxy reverso a servicios locales
  - Terminación SSL/TLS
  - Rate limiting
  - Health checks
  - Compresión gzip
  - Redirección HTTP → HTTPS

### Routing

| Dominio | Puerto Local | Servicio | Certificado |
|---------|-------------|----------|-------------|
| `mobilepass.itass.cloud` | 3000 | Frontend (Next.js) | Wildcard *.itass.cloud |
| `wallet.itass.cloud` | 3001 | Backend API (Express) | Wildcard *.itass.cloud |

> **Nota**: Se usa un certificado wildcard `*.itass.cloud` para ambos dominios.

## 🔐 Certificados SSL

Los certificados están organizados en `certificates/api.itass.cloud/`:

### Certificado Wildcard *.itass.cloud
Certificado SSL comercial que cubre todos los subdominios:
- `certificate.crt` - Certificado del servidor
- `private.key` - Llave privada

**Dominios cubiertos:**
- `mobilepass.itass.cloud` (Frontend)
- `wallet.itass.cloud` (Backend API)
- Cualquier otro subdominio `*.itass.cloud`

> **Nota**: Los certificados de Apple Wallet PKPass están en el proyecto backend (`mobile-pass-backend/certs/`)

## 📦 Despliegue

### Prerrequisitos
- Docker y Docker Compose instalados
- Frontend corriendo en `localhost:3000`
- Backend corriendo en `localhost:3001`
- Certificados SSL configurados en `certificates/`

### Inicio Rápido

```bash
# 1. Verificar configuración antes de desplegar
./verify-nginx-config.sh

# 2. Desplegar todos los servicios
./deploy.sh

# 3. Ver logs
docker-compose logs -f

# 4. Verificar health checks
curl http://localhost/health
curl https://mobilepass.itass.cloud/health
curl https://wallet.itass.cloud/health

# 5. Verificar estado de los servicios
./check-status.sh
```

### Comandos Útiles

```bash
# Ver logs
docker-compose logs -f nginx

# Detener Nginx
docker-compose down

# Reiniciar Nginx
docker-compose restart

# Recargar configuración (sin downtime)
docker-compose exec nginx nginx -s reload

# Verificar configuración de Nginx
docker-compose exec nginx nginx -t

# Ver certificados montados
docker-compose exec nginx ls -la /etc/ssl/wallet/
docker-compose exec nginx ls -la /etc/ssl/api/
```

## 🔧 Configuración

### Configuración Modular (DRY - Don't Repeat Yourself)

La configuración usa archivos comunes para evitar duplicación:

- **`common-proxy-headers.conf`**: Headers de proxy compartidos
- **`common-ssl.conf`**: Configuración SSL/TLS compartida
- **`common-security-headers.conf`**: Headers de seguridad compartidos

**Beneficios:**
- ✅ Sin duplicación de headers
- ✅ Mantenimiento centralizado
- ✅ Fácil agregar nuevos dominios
- ✅ Consistencia en toda la configuración

Ver [`NGINX-CONFIGURATION.md`](./NGINX-CONFIGURATION.md) para documentación técnica detallada.

### Health Checks

Nginx responde en el endpoint `/health`:

- `http://localhost/health` - Health check general
- `https://mobilepass.itass.cloud/health` - Frontend health
- `https://wallet.itass.cloud/health` - Backend API health

### Puertos

- **443**: HTTPS (SSL/TLS) - **Solo puerto seguro habilitado**
- Puerto 80 deshabilitado por seguridad (Virtual Server NIS maneja la redirección HTTP→HTTPS)

### Rate Limiting

Configurado para proteger la API:
- **API general**: 10 req/s con burst de 20
- **Endpoints de autenticación**: 5 req/s con burst de 5

## 🛡️ Seguridad

### SSL/TLS
- **Solo HTTPS habilitado (Puerto 443)** - Máxima seguridad
- Protocolos: TLS 1.2 y 1.3
- Ciphers fuertes configurados
- HSTS habilitado (max-age: 2 años)
- Puerto 80 deshabilitado por política de seguridad

### Headers de Seguridad
- `Strict-Transport-Security` - Force HTTPS
- `X-Frame-Options: SAMEORIGIN` - Previene clickjacking
- `X-Content-Type-Options: nosniff` - Previene MIME sniffing

### CORS
Configurado en el backend para permitir comunicación desde el frontend:
- Origin: `https://mobilepass.itass.cloud`
- Methods: GET, POST, PUT, DELETE, OPTIONS
- Headers: Content-Type, Authorization

### WebSocket Support
Soporte completo para WebSocket y Server-Sent Events:
- Headers `Upgrade` y `Connection` configurados
- Timeouts largos para conexiones persistentes
- Compatible con Next.js Hot Module Replacement (HMR)

## 📊 Monitoreo

### Logs de Nginx

Los logs están dentro del contenedor:
```bash
# Access logs
docker-compose exec nginx tail -f /var/log/nginx/access.log

# Error logs
docker-compose exec nginx tail -f /var/log/nginx/error.log
```

### Verificar Estado

```bash
# Estado del contenedor
docker-compose ps

# Health check
docker-compose exec nginx wget --spider http://127.0.0.1:80/health
```

## 🔄 Actualización

### Actualizar Certificados SSL

```bash
# 1. Copiar nuevos certificados
cp nuevo-certificate.crt certificates/api.itass.cloud/certificate.crt
cp nuevo-private.key certificates/api.itass.cloud/private.key

# 2. Verificar certificado
openssl x509 -in certificates/api.itass.cloud/certificate.crt -text -noout

# 3. Recargar Nginx sin downtime
docker-compose exec nginx nginx -s reload

# O reiniciar completamente
docker-compose restart nginx
```

### Actualizar Configuración

```bash
# 1. Editar archivos de configuración
# - nginx.conf (configuración principal)
# - conf.d/pass-generator.conf (routing por dominio)
# - conf.d/common-*.conf (configuración compartida)

# 2. Verificar sintaxis y configuración
./verify-nginx-config.sh

# 3. Si todo está OK, recargar
docker-compose exec nginx nginx -s reload

# O usar el script de despliegue
./deploy.sh
```

## 🐛 Troubleshooting

### El contenedor no inicia

```bash
# Ver logs del contenedor
docker-compose logs nginx

# Verificar que los puertos no estén en uso
netstat -ano | findstr ":80"
netstat -ano | findstr ":443"
```

### Error de certificados

```bash
# Verificar que los certificados existan
ls -la certificates/api.itass.cloud/

# Verificar certificado es válido
openssl x509 -in certificates/api.itass.cloud/certificate.crt -text -noout

# Verificar permisos dentro del contenedor
docker-compose exec nginx ls -la /etc/ssl/itass/

# Verificar que el certificado coincide con la llave privada
openssl x509 -noout -modulus -in certificates/api.itass.cloud/certificate.crt | openssl md5
openssl rsa -noout -modulus -in certificates/api.itass.cloud/private.key | openssl md5
```

### Error "502 Bad Gateway"

Esto indica que Nginx no puede conectarse a los servicios backend:

```bash
# Verificar que el frontend esté corriendo en localhost:3000
curl http://localhost:3000

# Verificar que el backend esté corriendo en localhost:3001
curl http://localhost:3001

# Ver logs de Nginx para más detalles
docker-compose logs -f nginx
```

### Error de configuración de Nginx

```bash
# Verificar sintaxis de configuración
docker-compose exec nginx nginx -t

# Si hay errores, revisar los archivos:
# - nginx.conf
# - conf.d/pass-generator.conf
```

## 📝 Notas

- Nginx usa red bridge interna de Docker para comunicarse con los servicios
- Los certificados se montan como read-only (`:ro`) por seguridad
- El caché de Nginx se almacena en un volumen persistente
- La configuración soporta HTTP/2 para mejor rendimiento
- Los certificados de Apple Wallet PKPass están en `mobile-pass-backend/certs/`
- Configuración modular usando `include` para evitar duplicación
- Compatible con Virtual Server NIS y múltiples dominios

## 🆕 Cambios Recientes (Virtual Server NIS)

### ¿Qué cambió?

**Antes:**
- Fortinet con IP Virtual haciendo NAT
- Tráfico directo al servidor local

**Ahora:**
- Virtual Server NIS enruta múltiples dominios
- Nginx recibe tráfico y lo distribuye internamente

### Mejoras Implementadas

1. **Configuración Modular**: Sin duplicación de headers ni SSL config
2. **WebSocket Support**: Para Next.js HMR y aplicaciones real-time
3. **Security Headers**: Headers de seguridad completos
4. **Rate Limiting**: Protección contra abuse
5. **Scripts de Verificación**: `verify-nginx-config.sh` para validar antes de desplegar
6. **Documentación Técnica**: Ver [`NGINX-CONFIGURATION.md`](./NGINX-CONFIGURATION.md)

## 🔗 Referencias

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Nginx Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [SSL/TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)
- [Nginx Rate Limiting](https://www.nginx.com/blog/rate-limiting-nginx/)
- **[NGINX-CONFIGURATION.md](./NGINX-CONFIGURATION.md)** - Documentación técnica detallada

