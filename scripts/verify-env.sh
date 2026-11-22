#!/usr/bin/env bash
# Checks the local toolchain and the Docker MySQL. Run from the repo root: ./scripts/verify-env.sh
set -u
ok=0; fail=0
check() { # name, command
  if out=$(eval "$2" 2>&1); then echo "PASS  $1: $(echo "$out" | head -1)"; ok=$((ok+1))
  else echo "FAIL  $1: $(echo "$out" | head -1)"; fail=$((fail+1)); fi
}
check "git"            "git --version"
check "gh logged in"   "gh auth status 2>&1 | grep -m1 'Logged in'"
check "java 21"        "java -version 2>&1 | grep -m1 '\"21'"
check "JAVA_HOME"      "test -n \"\${JAVA_HOME:-}\" && echo \$JAVA_HOME"
check "maven"          "mvn -v | head -1"
check "node >= 20"     "node -v | grep -E '^v(2[0-9]|[3-9][0-9])'"
check "npm"            "npm -v"
check "docker daemon"  "docker info --format '{{.ServerVersion}}'"
check ".env present"   "test -f .env && echo found"
if [ -f .env ]; then
  set -a; . ./.env; set +a
  check "mysql container healthy" "docker inspect -f '{{.State.Health.Status}}' lms-mysql | grep -x healthy"
  check "mysql 8 + utf8mb4" "docker exec lms-mysql mysql -u\"$MYSQL_USER\" -p\"$MYSQL_PASSWORD\" -N -e \"SELECT CONCAT(VERSION(),' ',@@character_set_server)\" 2>/dev/null | grep -E '^8\\..*utf8mb4'"
fi
echo; echo "$ok passed, $fail failed"; [ "$fail" -eq 0 ]
