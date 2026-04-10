import json
import subprocess
import questionary
from rich.console import Console
from .utils import generate_password


def app():
    print("🚀 Welcome to your AWS PaaS Builder\n")

    project_name = questionary.text(
        "What is the name of this project?",
        validate=lambda text: len(text) > 0 or "Project name cannot be empty.",
    ).ask()

    repo_url = questionary.text(
        "What is the Git repository URL?",
        validate=lambda text: len(text) > 0 or "You must provide a repository URL.",
    ).ask()

    runtime = questionary.select(
        "What is the application runtime?",
        choices=["Node.js", "Python", "Static HTML", "Docker"],
    ).ask()

    database_engine = questionary.select(
        "Which managed database engine do you need?",
        choices=["postgres", "mysql", "mariadb"],
    ).ask()

    # Create a safe default by removing non-alphanumeric characters
    safe_default_db = "".join(e for e in project_name if e.isalnum()) + "db"

    db_name = questionary.text(
        "Database name (Letters/Numbers ONLY):",
        default=safe_default_db,
        validate=lambda text: (
            text.isalnum()
            or "AWS strictly requires DB names to only contain letters and numbers."
        ),
    ).ask()

    db_user = questionary.text(
        "Master username (Letters/Numbers ONLY):",
        default="admin",
        validate=lambda text: (
            text.isalnum() or "Username must be only letters and numbers."
        ),
    ).ask()
    db_password = questionary.password(
        "Master password (leave blank to auto-generate):",
        validate=lambda text: (
            len(text) == 0
            or len(text) >= 8
            or "AWS requires the password to be at least 8 characters long."
        ),
    ).ask()

    if not db_password:
        db_password = generate_password()
        print(f"🔑 Auto-generated DB Password: {db_password} (Save this!)")

    instance_type = questionary.select(
        "Select EC2 Instance Power:", choices=["t3.micro", "t3.small", "t3.medium"]
    ).ask()

    # Generate Config
    tf_vars = {
        "project_name": project_name.lower().replace(" ", "-"),
        "repo_url": repo_url,
        "runtime": runtime,
        "db_engine": database_engine,
        "db_name": db_name,
        "db_user": db_user,
        "db_password": db_password,
        "instance_type": instance_type,
    }

    with open("terraform.tfvars.json", "w") as f:
        json.dump(tf_vars, f, indent=4)

    if questionary.confirm("Provision Managed Infrastructure?").ask():
        console = Console()

        with console.status("[bold blue]Initializing Terraform...", spinner="dots"):
            subprocess.run(["terraform", "init"], capture_output=True, check=True)
        console.print("[bold green]✅ Terraform Initialized[/bold green]")

        # Provisioning Spinner (This hides the 5-minute wait for the DB)
        with console.status(
            "[bold yellow]🏗️ Provisioning AWS Infrastructure (This usually takes 5-8 minutes)...",
            spinner="bouncingBar",
        ):
            try:
                # capture_output=True hides the messy Terraform logs
                subprocess.run(
                    ["terraform", "apply", "-auto-approve"],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                console.print("\n[bold green]🎉 Deployment Complete![/bold green]")

                # Let's run a quick command to grab the final outputs
                output = subprocess.run(
                    ["terraform", "output", "-json"], capture_output=True, text=True
                )
                outputs = json.loads(output.stdout)

                print(f"\n🌐 Website IP: {outputs.get('public_ip', {}).get('value')}")
                print(
                    f"🗄️ Database Endpoint: {outputs.get('db_endpoint', {}).get('value')}\n"
                )

            except subprocess.CalledProcessError as e:
                console.print("\n[bold red]❌ Deployment Failed![/bold red]")
                print("Here is the error log from Terraform:\n")
                print(e.stderr)  # If it breaks, we print the error so you can debug it
