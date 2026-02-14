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
    echo "📝 Creating .env file from example..."
    cp .env.example .env
    # Set auto-generated secret key
    sed -i "s/your-secret-key-here/$(python3 -c 'import secrets; print(secrets.token_hex(32))')/" .env
    # Auto-detect IP for ALLOWED_HOSTS
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "localhost")
    sed -i "s/yourapp.com,api.yourapp.com/$PUBLIC_IP,localhost,127.0.0.1/" .env
    echo "✅ .env created. Please edit it to add DB and AWS credentials if needed."
fi

# Run migrations
echo "🗄️ Running database migrations..."
python manage.py migrate

# Collect static files
echo "📁 Collecting static files..."
python manage.py collectstatic --noinput

# Create media directory (fallback if non-S3)
mkdir -p media

# Setup Gunicorn Systemd service
echo "⚙️ Setting up Gunicorn service..."
GUNICORN_SERVICE="[Unit]
Description=gunicorn daemon for Latent Social Network
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/venv/bin/gunicorn --workers 3 --bind unix:$(pwd)/latent.sock latent_backend.wsgi:application

[Install]
WantedBy=multi-user.target"

echo "$GUNICORN_SERVICE" | sudo tee /etc/systemd/system/latent.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable latent.service

echo "✅ Gunicorn systemd service created and enabled."

echo ""
echo "🚀 Deployment complete!"
echo ""
echo "To manage your server:"
echo "  sudo systemctl start latent    # Start"
echo "  sudo systemctl restart latent  # Restart"
echo "  sudo systemctl status latent   # Status"
echo "  journalctl -u latent -f        # View logs"
echo ""
echo "Next steps:"
echo "1. Configure Nginx to proxy to $(pwd)/latent.sock"
echo "2. Edit .env with your production database and S3 settings"
echo "3. Restart the service: sudo systemctl restart latent"
