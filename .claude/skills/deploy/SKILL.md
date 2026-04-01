# /deploy

Deploy the Fence backend to social.voltvoice.io.

## When to use
When the user invokes `/deploy` or asks to deploy to production.

## Instructions

Deploy the Fence backend to the production server. Stop and report if any step fails.

### Server details
- Host: `207.5.207.232`
- User: `ubuntu`
- SSH key: `~/.ssh/EricMacRumble.pem`
- SSH command: `ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232`
- Deploy path: `~/fence-deploy`
- App subdirectory: `~/fence-deploy/fence`
- Docker Compose file: `docker-compose.prod.yml`

### Step 1: Ensure local changes are pushed

Check that the local `master` branch is clean and pushed to origin. If there are unpushed commits, push them (or ask first if there are uncommitted changes).

```bash
git status --short
git diff origin/master..master --stat
```

If there are unpushed commits: `git push origin master`

### Step 2: Pull latest code on server

```bash
ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232 "cd ~/fence-deploy && git pull origin master"
```

### Step 3: Ensure .env symlink exists

The `.env` file should be a symlink to `.env.production`. Verify it exists:

```bash
ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232 "ls -la ~/fence-deploy/fence/.env"
```

If missing: `ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232 "cd ~/fence-deploy/fence && ln -s .env.production .env"`

### Step 4: Rebuild and restart containers

Use a 300s timeout — the build takes a few minutes.

```bash
ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232 "cd ~/fence-deploy/fence && docker compose -f docker-compose.prod.yml up -d --build"
```

### Step 5: Run database migrations

The migration command uses `Fence.Release.migrate()` via the release eval:

```bash
ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232 "cd ~/fence-deploy/fence && docker compose -f docker-compose.prod.yml exec app bin/fence eval 'Fence.Release.migrate()'"
```

### Step 6: Verify deployment

Check container status:

```bash
ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232 "cd ~/fence-deploy/fence && docker compose -f docker-compose.prod.yml ps"
```

Verify API is responding (should return 401 Unauthorized without a token):

```bash
ssh -i ~/.ssh/EricMacRumble.pem ubuntu@207.5.207.232 "curl -s -w '\nHTTP %{http_code}' http://localhost:4000/api/v1/me"
```

Report the result of each step to the user.
