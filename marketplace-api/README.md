# SocialMesh Widget Marketplace API

Backend API for the SocialMesh Widget Builder marketplace.

## Quick Start

### Local Development

```bash
# Install dependencies
npm install

# Run in development mode (with hot reload)
npm run dev

# Build for production
npm run build

# Run production build
npm start
```

### Docker

```bash
# Build and run with Docker Compose
docker-compose up --build

# Or build manually
docker build -t socialmesh-marketplace-api .
docker run -p 3000:3000 -v marketplace-data:/app/data socialmesh-marketplace-api
```

## API Endpoints

### Health Check
- `GET /health` - Returns API status

### Widgets

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/widgets/browse` | GET | Browse all widgets with pagination |
| `/widgets/featured` | GET | Get featured widgets |
| `/widgets/categories` | GET | List all categories |
| `/widgets/:id` | GET | Get widget details |
| `/widgets/:id/download` | GET | Download widget schema |
| `/widgets/upload` | POST | Upload new widget (auth required) |
| `/widgets/:id/rate` | POST | Rate a widget (auth required) |
| `/widgets/:id/report` | POST | Report a widget (auth required) |

### Query Parameters for `/widgets/browse`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | number | 1 | Page number |
| `limit` | number | 20 | Items per page (max 100) |
| `category` | string | - | Filter by category |
| `sort` | string | downloads | Sort by: downloads, rating, newest, name |
| `q` | string | - | Search query |

## Deployment

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Server port |
| `NODE_ENV` | development | Environment |
| `DATABASE_PATH` | ./data/marketplace.db | SQLite database path |

### Deploy to Cloud

The API is ready to deploy to any container platform:

- **Docker Hub**: Push the image and deploy
- **AWS ECS/Fargate**: Use the Docker image
- **Google Cloud Run**: Deploy container
- **Azure Container Apps**: Deploy container
- **Railway/Render/Fly.io**: Connect repo and deploy

### Production Checklist

- [ ] Configure CORS for production domain
- [ ] Set up authentication (Firebase Auth, Auth0, etc.)
- [ ] Add SSL/TLS termination (via reverse proxy)
- [ ] Set up monitoring and logging
- [ ] Configure backup for SQLite database
- [ ] Consider migrating to PostgreSQL for scale
