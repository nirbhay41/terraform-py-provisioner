variable "repo_url" { type = string }
variable "project_name" { type = string }
variable "db_engine" { type = string } # e.g. "postgres" or "mysql"
variable "db_name" { type = string }
variable "db_user" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "instance_type" { default = "t3.micro" }

provider "aws" { region = "ap-south-1" }

# Data source to fetch the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security Group for EC2
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP and SSH inbound traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for RDS
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Allow inbound DB traffic"

  # Allow from EC2 Instance specifically
  ingress {
    from_port       = var.db_engine == "postgres" ? 5432 : 3306
    to_port         = var.db_engine == "postgres" ? 5432 : 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  # Allow Public Access
  ingress {
    from_port   = var.db_engine == "postgres" ? 5432 : 3306
    to_port     = var.db_engine == "postgres" ? 5432 : 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic from the DB
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed RDS Instance
resource "aws_db_instance" "default" {
  allocated_storage      = 20
  identifier             = "${var.project_name}-db"
  engine                 = var.db_engine
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = true
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx git python3-pip python3-venv libpq-dev
              
              cd /var/www
              git clone ${var.repo_url} app
              cd app

              # Create the .env file dynamically mapped to the RDS instance
              cat << 'ENV' > .env
              API_KEY=protiviti-poc-key-2024
              INTERNAL_TOKEN=protiviti-internal-token-2024
              DATABASE_NAME=${var.db_name}
              DATABASE_USER=${var.db_user}
              DATABASE_PASSWORD=${var.db_password}
              DATABASE_HOST=${aws_db_instance.default.address}
              DATABASE_PORT=${aws_db_instance.default.port}
              ENV

              python3 -m venv venv
              source venv/bin/activate

              pip install -r requirements.txt
              pip install gunicorn psycopg2-binary python-dotenv

              # Run Django commands BEFORE starting the service
              python manage.py migrate
              python manage.py seed_demo_data
              # python manage.py collectstatic --noinput

              # Setup Gunicorn as a Background Service
              cat << 'SVC' > /etc/systemd/system/myapp.service
              [Unit]
              Description=Gunicorn daemon for Django
              After=network.target

              [Service]
              User=root
              Group=www-data
              WorkingDirectory=/var/www/app
              Environment="PATH=/var/www/app/venv/bin"
              ExecStart=/var/www/app/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 protiviti_portal.wsgi:application

              [Install]
              WantedBy=multi-user.target
              SVC

              systemctl start myapp
              systemctl daemon-reload
              systemctl enable myapp

              # Configure Nginx to serve Django and Static Files
              cat << 'NGINX' > /etc/nginx/sites-available/default
              server {
                  listen 80;
                  server_name _;

                  location = /favicon.ico { access_log off; log_not_found off; }
                  
                  location /static/ {
                      root /var/www/app;
                  }

                  location / {
                      proxy_pass http://127.0.0.1:8000;
                      proxy_set_header Host $${host};
                      proxy_set_header X-Real-IP $${remote_addr};
                  }
              }
              NGINX

              systemctl restart nginx
              EOF

  tags = { Name = var.project_name }
}

output "public_ip" { value = aws_instance.web.public_ip }
output "db_endpoint" { value = aws_db_instance.default.endpoint }
output "var_repo_url" { value = var.repo_url }
output "var_project_name" { value = var.project_name }
output "var_db_engine" { value = var.db_engine }
output "var_db_name" { value = var.db_name }
output "var_db_user" { value = var.db_user }
output "var_db_password" {
  value     = var.db_password
  sensitive = true
}
output "var_instance_type" { value = var.instance_type }
