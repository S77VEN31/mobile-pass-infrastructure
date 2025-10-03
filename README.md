# Pass Generator Infrastructure

Configuración de Nginx como reverse proxy para el proyecto Pass Generator. Esta infraestructura maneja el enrutamiento SSL/TLS para los dominios `wallet.itass.cloud` (frontend) y `api.itass.cloud` (backend).

## 📋 Estructura

```
pass-generator-infrastructure/
├── docker-compose.yml          # Nginx en contenedor
├── nginx.conf                  # Configuración principal de Nginx
├── conf.d/
│   └── pass-generator.conf     # Configuración de virtual hosts
└── certificates/               # Certificados SSL organizados por dominio
    ├── wallet.itass.cloud/     # Frontend (Let's Encrypt)
    │   ├── fullchain.pem
    │   └── privkey.pem
    └── api.itass.cloud/        # Backend (SSL Comercial)
        ├── certificate.crt
        ├── private.key
        └── ca_bundle.crt
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
| `wallet.itass.cloud` | 3000 | Frontend (Next.js) | Let's Encrypt |
| `api.itass.cloud` | 3001 | Backend (Express) | SSL Comercial |

## 🔐 Certificados SSL

Los certificados están organizados por dominio en `certificates/`:

### Frontend - wallet.itass.cloud
Certificados Let's Encrypt para el dominio del frontend:
- `fullchain.pem` - Cadena completa de certificados
- `privkey.pem` - Llave privada

### Backend - api.itass.cloud
Certificados SSL comerciales para el dominio del backend:
- `certificate.crt` - Certificado del servidor
- `private.key` - Llave privada
- `ca_bundle.crt` - Bundle de CA intermedio

> **Nota**: Los certificados de Apple Wallet están en el proyecto backend (`pass-generator-backend/certs/`)

## 📦 Despliegue

### Prerrequisitos
- Docker y Docker Compose instalados
- Frontend corriendo en `localhost:3000`
- Backend corriendo en `localhost:3001`
- Certificados SSL configurados en `certificates/`

### Inicio Rápido

```bash
# 1. Verificar que los servicios locales estén corriendo
# Frontend: localhost:3000
# Backend: localhost:3001

# 2. Iniciar Nginx
docker-compose up -d

# 3. Ver logs
docker-compose logs -f

# 4. Verificar health checks
curl http://localhost/health
curl https://wallet.itass.cloud/health
curl https://api.itass.cloud/health
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

### Health Checks

Nginx responde en el endpoint `/health`:

- `http://localhost/health` - Health check general
- `https://wallet.itass.cloud/health` - Frontend health
- `https://api.itass.cloud/health` - Backend health

### Puertos

- **80**: HTTP (redirige a HTTPS automáticamente)
- **443**: HTTPS (SSL/TLS)

### Rate Limiting

Configurado para proteger la API:
- **API general**: 10 req/s con burst de 20
- **Endpoints de autenticación**: 5 req/s con burst de 5

## 🛡️ Seguridad

### SSL/TLS
- Protocolos: TLS 1.2 y 1.3
- Ciphers fuertes configurados
- HSTS habilitado (max-age: 2 años)
- HTTP redirige automáticamente a HTTPS

### Headers de Seguridad
- `Strict-Transport-Security` - Force HTTPS
- `X-Frame-Options: SAMEORIGIN` - Previene clickjacking
- `X-Content-Type-Options: nosniff` - Previene MIME sniffing

### CORS
Configurado para permitir comunicación entre frontend y backend:
- Origin: `https://wallet.itass.cloud`
- Methods: GET, POST, PUT, DELETE, OPTIONS
- Headers: Content-Type, Authorization

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
# 1. Copiar nuevos certificados a las carpetas correspondientes
cp nuevo-fullchain.pem certificates/wallet.itass.cloud/fullchain.pem
cp nuevo-privkey.pem certificates/wallet.itass.cloud/privkey.pem

# 2. Recargar Nginx sin downtime
docker-compose exec nginx nginx -s reload

# O reiniciar completamente
docker-compose restart
```

### Actualizar Configuración

```bash
# 1. Editar archivos de configuración
# nginx.conf o conf.d/pass-generator.conf

# 2. Verificar sintaxis
docker-compose exec nginx nginx -t

# 3. Recargar configuración
docker-compose exec nginx nginx -s reload
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
dir certificates\wallet.itass.cloud
dir certificates\api.itass.cloud

# Verificar permisos dentro del contenedor
docker-compose exec nginx ls -la /etc/ssl/wallet/
docker-compose exec nginx ls -la /etc/ssl/api/
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

- Nginx usa `network_mode: host` para acceder a servicios en localhost
- Los certificados se montan como read-only (`:ro`)
- El caché de Nginx se almacena en un volumen persistente
- La configuración soporta HTTP/2 para mejor rendimiento
- Los certificados de Apple Wallet están en `pass-generator-backend/certs/`

## 🔗 Referencias

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [SSL/TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)

