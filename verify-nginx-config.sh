#!/bin/bash
# Script de verificación de configuración Nginx
# Usage: ./verify-nginx-config.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=================================="
echo "Verificación de Configuración Nginx"
echo "=================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker no está corriendo${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker está corriendo"

# Check if required files exist
echo ""
echo "Verificando archivos de configuración..."

FILES=(
    "nginx.conf"
    "conf.d/pass-generator.conf"
    "conf.d/common-proxy-headers.conf"
    "conf.d/common-ssl.conf"
    "conf.d/common-security-headers.conf"
    "certificates/api.itass.cloud/certificate.crt"
    "certificates/api.itass.cloud/private.key"
)

ALL_FILES_OK=true
for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file"
    else
        echo -e "${RED}❌${NC} $file - No encontrado"
        ALL_FILES_OK=false
    fi
done

if [ "$ALL_FILES_OK" = false ]; then
    echo -e "\n${RED}Faltan archivos requeridos${NC}"
    exit 1
fi

# Check certificate validity
echo ""
echo "Verificando certificados SSL..."
if openssl x509 -checkend 86400 -noout -in certificates/api.itass.cloud/certificate.crt > /dev/null 2>&1; then
    EXPIRY_DATE=$(openssl x509 -enddate -noout -in certificates/api.itass.cloud/certificate.crt | cut -d= -f2)
    echo -e "${GREEN}✓${NC} Certificado válido (expira: $EXPIRY_DATE)"
else
    echo -e "${YELLOW}⚠${NC} Certificado expirará en menos de 24 horas"
fi

# Test Nginx configuration syntax with temporary container
echo ""
echo "Verificando sintaxis de Nginx..."

# Check if nginx container is running
if docker ps --format '{{.Names}}' | grep -q "pass-generator-nginx"; then
    if docker exec pass-generator-nginx nginx -t 2>&1; then
        echo -e "${GREEN}✓${NC} Sintaxis de Nginx correcta"
    else
        echo -e "${RED}❌${NC} Error en sintaxis de Nginx"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠${NC} Contenedor Nginx no está corriendo"
    echo "   Intentando verificación con contenedor temporal..."
    
    # Create temporary nginx container to test configuration
    docker run --rm \
        -v "$SCRIPT_DIR/nginx.conf:/etc/nginx/nginx.conf:ro" \
        -v "$SCRIPT_DIR/conf.d:/etc/nginx/conf.d:ro" \
        -v "$SCRIPT_DIR/certificates/api.itass.cloud/certificate.crt:/etc/ssl/itass/certificate.crt:ro" \
        -v "$SCRIPT_DIR/certificates/api.itass.cloud/private.key:/etc/ssl/itass/private.key:ro" \
        nginx:alpine nginx -t 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Sintaxis de Nginx correcta (verificado con contenedor temporal)"
    else
        echo -e "${RED}❌${NC} Error en sintaxis de Nginx"
        exit 1
    fi
fi

# Check for common issues
echo ""
echo "Verificando configuración común..."

# Check for duplicate headers
DUPLICATE_COUNT=$(grep -r "proxy_set_header" conf.d/pass-generator.conf | grep -v "include" | wc -l)
if [ "$DUPLICATE_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No hay headers duplicados en pass-generator.conf (usando includes)"
else
    echo -e "${YELLOW}⚠${NC} Se encontraron $DUPLICATE_COUNT proxy_set_header en pass-generator.conf"
    echo "   Considera usar 'include common-proxy-headers.conf' en su lugar"
fi

# Check for WebSocket support
if grep -q "connection_upgrade" nginx.conf; then
    echo -e "${GREEN}✓${NC} Soporte WebSocket configurado"
else
    echo -e "${YELLOW}⚠${NC} Soporte WebSocket no encontrado"
fi

# Check rate limiting
if grep -q "limit_req_zone" nginx.conf; then
    echo -e "${GREEN}✓${NC} Rate limiting configurado"
else
    echo -e "${YELLOW}⚠${NC} Rate limiting no configurado"
fi

# Summary
echo ""
echo "=================================="
echo -e "${GREEN}✓ Verificación completada${NC}"
echo "=================================="
echo ""
echo "Siguiente paso: Desplegar con 'docker-compose up -d'"

