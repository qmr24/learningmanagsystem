# Local setup guide (macOS, Apple Silicon or Intel)

Target: Java 21, Maven, Node 22, Docker (MySQL 8), IntelliJ IDEA, VS Code, GitHub CLI.
Run everything in Terminal. If a tool is already installed, skip that line.

## 1. Command-line tools and Homebrew
```bash
xcode-select --install                     # Git + compilers; accept the popup
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Follow the "Next steps" Homebrew prints (adds brew to your PATH), then:
brew --version
```

## 2. Install the toolchain
```bash
brew install git gh maven node@22
brew install --cask temurin@21             # Java 21 JDK
brew install --cask docker                 # Docker Desktop
brew install --cask visual-studio-code
brew install --cask intellij-idea          # skip if already installed
```
Open **Docker Desktop** once from Applications, accept the prompts and wait until it says "running".

Make Java 21 the default and Node 22 available (zsh):
```bash
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 21)' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:/opt/homebrew/opt/node@22/bin:$PATH"' >> ~/.zshrc   # Intel Mac: /usr/local/opt/node@22/bin
source ~/.zshrc
```

## 3. GitHub access
```bash
git config --global user.name  "Your Name"
git config --global user.email "your-github-email@example.com"
gh auth login          # GitHub.com -> HTTPS -> Login with a web browser
gh auth status
```

## 4. Get the project
```bash
mkdir -p ~/projects && cd ~/projects
gh repo clone qmr24/learningmanagsystem
cd learningmanagsystem
git fetch --all
git checkout phase-1-setup        # until it is merged into main; later: git checkout main && git pull
```

## 5. Configure MySQL with Docker
```bash
cp .env.example .env              # then edit .env and set your own passwords
open -e .env
docker compose up -d
docker compose ps                 # STATUS should become "healthy" (about 20-30 s)
```
If port 3306 is already used (for example a Homebrew MySQL), set `MYSQL_PORT=3307` in `.env` and run `docker compose up -d` again. Stop a Homebrew MySQL with `brew services stop mysql`.

Useful commands:
```bash
docker compose logs -f mysql                       # watch logs
docker compose stop                                # stop, keep data
docker compose down                                # remove container, keep data volume
docker compose down -v                             # DELETE all database data (fresh start)
docker exec -it lms-mysql mysql -ulms_user -p lms  # open a SQL shell
```

## 6. Test the Phase 1 schema on your real MySQL
This is the check I could not run myself. It loads the V1 file into a throwaway database, counts tables, then drops it.
```bash
set -a; . ./.env; set +a
SQL=backend/src/main/resources/db/migration/V1__core_schema.sql
docker exec lms-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS lms_scratch; CREATE DATABASE lms_scratch CHARACTER SET utf8mb4;"
docker exec -i lms-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" lms_scratch < "$SQL"
docker exec lms-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='lms_scratch' AND table_type='BASE TABLE';"   # expect 32 (plus 1 view)
docker exec lms-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE lms_scratch;"
```
A "Using a password on the command line" warning is normal. If you see `ERROR 1234 ...`, copy the full message to me.

## 7. Verify the whole environment
```bash
./scripts/verify-env.sh
```
Every line should say PASS. Quick manual versions:
```bash
java -version      # openjdk 21.x
mvn -v             # Apache Maven 3.9+, Java version: 21
node -v && npm -v  # v22.x
docker --version && docker compose version
gh auth status
```

## 8. IntelliJ IDEA, VS Code and GitHub
**IntelliJ IDEA (backend).** Phase 2 adds `backend/pom.xml`. Then: File > Open > select `backend/pom.xml` > "Open as Project". Set File > Project Structure > SDK to the Temurin 21 JDK. Maven reloads dependencies automatically. For Git: Settings > Version Control > GitHub > "+" > Log In via GitHub (or just use the terminal; IntelliJ reuses your git config and the credentials `gh` stored).
Run configurations will read environment variables; in Phase 2 we use `DB_URL`, `DB_USER`, `DB_PASSWORD` from your `.env` values.

**VS Code (frontend, docs, SQL).** Run `code .` in the repo root (Command Palette > "Shell Command: Install 'code' command in PATH" if missing). Install: *Extension Pack for Java* (optional), *ESLint*, *Tailwind CSS IntelliSense*, *Prettier*, *GitHub Pull Requests*, *Database Client* (to browse MySQL at 127.0.0.1:3306).

**Git workflow we will use.** One branch per phase, and `main` only receives merged, tested work:
```bash
git checkout main && git pull
git checkout -b phase-2-backend-foundation
# ... work, test ...
git add -A && git commit -m "Phase 2: ..."
git push -u origin phase-2-backend-foundation
gh pr create --fill          # review on GitHub, then merge
```

## 9. Troubleshooting
| Symptom | Fix |
|---|---|
| `docker: Cannot connect to the Docker daemon` | Open Docker Desktop and wait until it is running |
| `java -version` shows 17 or 11 | Re-run the `JAVA_HOME` lines in step 2 and open a new terminal |
| Port 3306 in use | Set `MYSQL_PORT=3307` in `.env`; remember it in the JDBC URL |
| Container keeps restarting | `docker compose logs mysql`; often a bad `.env` value. `docker compose down -v` then up again |
| `Access denied for user` | Passwords in `.env` changed after first start; `docker compose down -v` to recreate |
