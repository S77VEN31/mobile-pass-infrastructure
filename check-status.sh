#!/bin/bash

# Script para verificar el estado del sistema
# Ejecutar con: bash check-status.sh

echo "🔍 Verificando estado del sistema Pass Generator..."

# 1. Verificar contenedores
echo ""
echo "📦 Estado de contenedores:"
sudo docker-compose ps

# 2. Verificar certificados
echo ""
echo "🔐 Verificando certificados SSL:"
if [ -f "certificates/wallet.itass.cloud/fullchain.pem" ]; then
    echo "✅ Frontend cert: $(openssl x509 -in certificates/wallet.itass.cloud/fullchain.pem -noout -subject -dates 2>/dev/null | head -1)"
else
    echo "❌ Frontend cert: No encontrado"
fi

if [ -f "certificates/api.itass.cloud/certificate.crt" ]; then
    echo "✅ Backend cert: $(openssl x509 -in certificates/api.itass.cloud/certificate.crt -noout -subject -dates 2>/dev/null | head -1)"
else
    echo "❌ Backend cert: No encontrado"
fi

# 3. Verificar puertos
echo ""
echo "🌐 Verificando puertos:"
netstat -tlnp | grep -E ":(80|443|3000|3001)" || echo "⚠️  No se encontraron puertos abiertos"

# 4. Health checks
echo ""
echo "🏥 Health checks:"
echo -n "   HTTP Health: "
curl -s http://localhost/health 2>/dev/null || echo "❌ No disponible"

echo -n "   Frontend Health: "
curl -s -k https://wallet.itass.cloud/health 2>/dev/null || echo "❌ No disponible"

echo -n "   Backend Health: "
curl -s -k https://api.itass.cloud/health 2>/dev/null || echo "❌ No disponible"

# 5. Verificar logs de errores
echo ""
echo "📋 Últimos errores en logs:"
sudo docker-compose logs --tail=10 | grep -i error || echo "✅ No se encontraron errores recientes"

echo ""
echo "✅ Verificación completada"
