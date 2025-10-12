# Configuración Nginx - Documentación

## Arquitectura de Red

### Antes
```
Internet → Fortinet (IP Virtual + NAT) → Servidor Local → Nginx → Servicios
```

### Ahora (con Virtual Server NIS)
```
Internet → Virtual Server NIS → Servidor Local → Nginx → Servicios
         (Múltiples dominios)                     (Enrutamiento)
```

## Estructura de Archivos

### Archivos Comunes (DRY - Don't Repeat Yourself)

1. **`conf.d/common-proxy-headers.conf`**
   - Headers de proxy compartidos
   - Soporte para WebSocket
   - Previene duplicación de headers
   - Se incluye en cada location de proxy

2. **`conf.d/common-ssl.conf`**
   - Configuración SSL/TLS compartida
   - Protocolos: TLSv1.2 y TLSv1.3
   - Ciphers seguros
   - OCSP Stapling
   - Se incluye en cada server block HTTPS

3. **`conf.d/common-security-headers.conf`**
   - Headers de seguridad HTTP
   - HSTS, X-Frame-Options, CSP, etc.
   - Se incluye en cada server block HTTPS

### Archivo Principal

4. **`conf.d/pass-generator.conf`**
   - Configuración principal de enrutamiento
   - Usa includes para evitar duplicación
   - Maneja múltiples dominios

## Enrutamiento por Dominio

### Dominios Configurados

| Dominio | Servicio | Puerto Interno | Descripción |
|---------|----------|----------------|-------------|
| `mobilepass.itass.cloud` | Frontend | 3000 | Next.js Application |
| `wallet.itass.cloud` | Backend | 3001 | Express.js API |

### Flujo de Solicitudes

```
1. Virtual Server NIS recibe solicitud en puerto 80/443
   ↓
2. Basado en el dominio, enruta al servidor local
   ↓
3. Nginx en servidor local recibe la solicitud
   ↓
4. Nginx identifica el dominio (server_name)
   ↓
5. Proxy hacia el contenedor correspondiente
   ↓
6. Contenedor procesa y responde
```

## Características de la Configuración

### ✅ Mejores Prácticas Implementadas

1. **Sin Duplicación de Headers**
   - Uso de includes para configuración común
   - Headers definidos una sola vez
   - Fácil mantenimiento

2. **Seguridad SSL/TLS**
   - TLS 1.2 y 1.3 únicamente
   - Ciphers fuertes (ECDHE, AES-GCM)
   - OCSP Stapling habilitado
   - Session cache optimizado

3. **Headers de Seguridad**
   - HSTS con preload
   - X-Frame-Options: SAMEORIGIN
   - X-Content-Type-Options: nosniff
   - CSP y Permissions-Policy

4. **Rate Limiting**
   - `/api/auth`: 5 req/s (autenticación)
   - `/api/`: 10 req/s (API general)
   - Burst configurado para picos de tráfico

5. **Health Checks**
   - Endpoint `/health` en HTTP y HTTPS
   - Sin redirección en HTTP para health checks
   - Respuestas específicas por servicio

6. **Soporte WebSocket**
   - Headers Upgrade y Connection configurados
   - Timeouts largos para conexiones persistentes
   - Compatible con Next.js HMR y SSE

7. **Logging**
   - Logs separados por servicio
   - Access log y error log independientes
   - Health checks sin logging (performance)

### 🔄 Compatibilidad con Virtual Server NIS

- **Recepción de tráfico**: Nginx puede recibir tráfico en cualquier puerto (80, 443)
- **Host header preservado**: El header `Host` se mantiene para identificar el dominio
- **X-Forwarded-* headers**: Se agregan para rastrear la IP real del cliente
- **SSL Termination**: Puede hacerse en NIS o en Nginx (actualmente en Nginx)

## Pruebas y Verificación

### Verificar Configuración

```bash
# Verificar sintaxis
docker exec pass-generator-nginx nginx -t

# Recargar configuración sin downtime
docker exec pass-generator-nginx nginx -s reload

# Ver logs en tiempo real
docker logs -f pass-generator-nginx
```

### Probar Endpoints

```bash
# Health checks
curl http://mobilepass.itass.cloud/health
curl http://wallet.itass.cloud/health

# Frontend
curl -I https://mobilepass.itass.cloud/

# Backend API
curl -I https://wallet.itass.cloud/api/health
```

### Verificar Headers

```bash
# Ver todos los headers de respuesta
curl -I https://mobilepass.itass.cloud/

# Verificar headers de seguridad
curl -I https://mobilepass.itass.cloud/ | grep -E "(Strict-Transport|X-Frame|X-Content)"

# Verificar SSL
openssl s_client -connect mobilepass.itass.cloud:443 -servername mobilepass.itass.cloud
```

## Troubleshooting

### Problema: Headers duplicados

**Síntoma**: Headers aparecen múltiples veces en la respuesta

**Solución**: 
- Verificar que no hay `proxy_set_header` duplicados
- Asegurar que solo se usa `include common-proxy-headers.conf` una vez
- Revisar que el backend no esté agregando headers que Nginx también agrega

### Problema: Rate limiting muy restrictivo

**Síntoma**: Errores 429 (Too Many Requests) frecuentes

**Solución**:
```nginx
# Ajustar en nginx.conf
limit_req_zone $binary_remote_addr zone=api:10m rate=20r/s;  # Aumentar de 10 a 20
limit_req_zone $binary_remote_addr zone=auth:10m rate=10r/s; # Aumentar de 5 a 10
```

### Problema: WebSocket no funciona

**Síntoma**: Conexiones WebSocket fallan o se cierran

**Solución**:
- Verificar que `map $http_upgrade $connection_upgrade` está en nginx.conf
- Asegurar que `proxy_read_timeout` es lo suficientemente largo
- Verificar logs: `docker logs pass-generator-nginx`

### Problema: SSL no funciona

**Síntoma**: Error de certificado o conexión rechazada

**Solución**:
```bash
# Verificar certificados existen
ls -la /home/mobilepass/apps/mobile-pass-infrastructure/certificates/api.itass.cloud/

# Verificar permisos
chmod 644 certificates/api.itass.cloud/certificate.crt
chmod 600 certificates/api.itass.cloud/private.key

# Verificar certificado es válido
openssl x509 -in certificates/api.itass.cloud/certificate.crt -text -noout
```

## Agregar Nuevos Dominios

Para agregar un nuevo dominio (ej: `api.itass.cloud`):

```nginx
# Agregar en pass-generator.conf
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.itass.cloud;

    ssl_certificate /etc/ssl/itass/certificate.crt;
    ssl_certificate_key /etc/ssl/itass/private.key;

    include /etc/nginx/conf.d/common-ssl.conf;
    include /etc/nginx/conf.d/common-security-headers.conf;

    location / {
        proxy_pass http://nuevo-servicio:puerto;
        include /etc/nginx/conf.d/common-proxy-headers.conf;
    }
}
```

## Mantenimiento

### Actualizar Configuración

1. Editar archivos de configuración
2. Verificar sintaxis: `docker exec pass-generator-nginx nginx -t`
3. Recargar: `docker exec pass-generator-nginx nginx -s reload`

### Renovar Certificados SSL

```bash
# Copiar nuevos certificados
cp nuevo-certificate.crt certificates/api.itass.cloud/certificate.crt
cp nuevo-private.key certificates/api.itass.cloud/private.key

# Recargar Nginx
docker-compose restart nginx
```

### Monitoreo

```bash
# Ver logs de acceso
docker exec pass-generator-nginx tail -f /var/log/nginx/access.log

# Ver logs de error
docker exec pass-generator-nginx tail -f /var/log/nginx/error.log

# Estadísticas de conexiones
docker exec pass-generator-nginx nginx -V 2>&1 | grep -o with-http_stub_status_module
```

## Referencias

- [Nginx Reverse Proxy Documentation](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Nginx SSL/TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)
- [Nginx Rate Limiting](https://www.nginx.com/blog/rate-limiting-nginx/)

