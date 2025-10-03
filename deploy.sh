#!/bin/bash

# Script de despliegue para Pass Generator
# Ejecutar con: bash deploy.sh

echo "🚀 Iniciando despliegue de Pass Generator..."

# 1. Verificar que estamos en el directorio correcto
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: No se encontró docker-compose.yml"
    echo "   Asegúrate de estar en el directorio mobile-pass-infrastructure"
    exit 1
fi

# 2. Detener contenedores existentes
echo "🛑 Deteniendo contenedores existentes..."
sudo docker-compose down

# 3. Limpiar imágenes anteriores (opcional)
echo "🧹 Limpiando imágenes anteriores..."
sudo docker system prune -f

# 4. Construir y desplegar todos los servicios
echo "🔨 Construyendo y desplegando servicios..."
sudo docker-compose up -d --build

# 5. Verificar que todos los servicios estén corriendo
echo "✅ Verificando estado de los servicios..."
sudo docker-compose ps

# 6. Mostrar logs de los últimos 50 líneas
echo "📋 Mostrando logs recientes..."
sudo docker-compose logs --tail=50

# 7. Verificar health checks
echo "🏥 Verificando health checks..."
echo "   - HTTP Health: http://localhost/health"
echo "   - Frontend Health: https://wallet.itass.cloud/health"
echo "   - Backend Health: https://api.itass.cloud/health"

echo ""
echo "🎉 ¡Despliegue completado!"
echo ""
echo "📱 URLs de acceso:"
echo "   - Frontend: https://wallet.itass.cloud"
echo "   - Backend API: https://api.itass.cloud"
echo ""
echo "🔧 Comandos útiles:"
echo "   - Ver logs: sudo docker-compose logs -f"
echo "   - Detener: sudo docker-compose down"
echo "   - Reiniciar: sudo docker-compose restart"
echo "   - Estado: sudo docker-compose ps"
