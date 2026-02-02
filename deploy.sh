#!/bin/bash
# Deployment script for AWS EC2
# Run this on your EC2 instance after SSH'ing in

set -e  # Exit on any error

echo "🚀 Starting Latent Social Network Deployment..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Python and dependencies
echo "🐍 Installing Python..."
sudo apt install -y python3 python3-pip python3-venv git nginx

# Clone or pull the repo
if [ -d "socialnetwork" ]; then
    echo "📥 Pulling latest code..."
    cd socialnetwork
    git pull origin main
else
    echo "📥 Cloning repository..."
    git clone https://github.com/ngosalwandoniza/socialnetwork.git
    cd socialnetwork
fi

# Create virtual environment
echo "🔧 Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file..."
    cat > .env << EOF
DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4),localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=
EOF
    echo "✅ .env created with auto-generated secret key"
fi

# Run migrations
echo "🗄️ Running database migrations..."
python manage.py migrate

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Create media directory
mkdir -p media

echo ""
echo "✅ Deployment complete!"
echo ""
echo "To start the server, run:"
echo "  source venv/bin/activate"
echo "  gunicorn latent_backend.wsgi:application --bind 0.0.0.0:8000 --daemon"
echo ""
echo "Your API will be available at:"
echo "  http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8000/api/"
