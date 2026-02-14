#!/bin/bash
set -e
echo "🚀 Starting Latent Social Network Deployment..."
sudo apt update && sudo apt install -y python3 python3-pip python3-venv git nginx
cd /home/ubuntu/socialnetwork
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file..."
    cat > .env << EENV
DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4),localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=
EENV
fi
python manage.py migrate
python manage.py collectstatic --noinput
mkdir -p media
echo "⚙️ Setting up Gunicorn service..."
GUNICORN_SERVICE="[Unit]
Description=gunicorn daemon for Latent Social Network
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=/home/ubuntu/socialnetwork
ExecStart=/home/ubuntu/socialnetwork/venv/bin/gunicorn --workers 3 --bind unix:/home/ubuntu/socialnetwork/latent.sock latent_backend.wsgi:application

[Install]
WantedBy=multi-user.target"
echo "$GUNICORN_SERVICE" | sudo tee /etc/systemd/system/latent.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable latent.service
sudo systemctl restart latent.service
echo "✅ Deployment complete and service started!"
