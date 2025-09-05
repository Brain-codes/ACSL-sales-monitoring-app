# Branch Management API Documentation

## Overview
The Branch Management API provides CRUD operations for managing organization branches. This API supports creating, reading, updating, and deleting branches within organizations.

## Base URL
```
/functions/v1/manage-branches
```

## Authentication
All endpoints require authentication. The API supports:
- **Super Admin**: Full access to all branches across all organizations
- **Organization Admin**: Access limited to their organization's branches only
- **Agent**: Read-only access to their organization's branches

## Endpoints

### 1. Get All Branches (Super Admin Only)
```http
GET /functions/v1/manage-branches
```

**Authorization**: Super Admin only

**Query Parameters**:
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (max: 100, default: 10)
- `search` (optional): Search in name, state, or LGA
- `country` (optional): Filter by country
- `state` (optional): Filter by state
- `organization_id` (optional): Filter by organization ID

**Response**:
```json
{
  "success": true,
  "message": "Branches fetched successfully",
  "data": {
    "branches": [
      {
        "id": "uuid",
        "organization_id": "uuid",
        "name": "Lagos Branch",
        "country": "Nigeria",
        "state": "Lagos",
        "lga": "Lagos Island",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z",
        "created_by": "uuid",
        "organizations": {
          "id": "uuid",
          "name": "ACSL Organization",
          "partner_email": "partner@acsl.com"
        },
        "profiles": {
          "id": "uuid",
          "full_name": "John Doe",
          "email": "john@example.com"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 25,
      "totalPages": 3,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

### 2. Get Branches by Organization
```http
GET /functions/v1/manage-branches/organization/{organization_id}
```

**Authorization**: Super Admin or Organization Admin

**Path Parameters**:
- `organization_id`: UUID of the organization

**Query Parameters**:
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (max: 100, default: 10)
- `search` (optional): Search in name, state, or LGA
- `country` (optional): Filter by country
- `state` (optional): Filter by state

**Response**:
```json
{
  "success": true,
  "message": "Organization branches fetched successfully",
  "data": {
    "organization": {
      "id": "uuid",
      "name": "ACSL Organization",
      "partner_email": "partner@acsl.com"
    },
    "branches": [
      {
        "id": "uuid",
        "organization_id": "uuid",
        "name": "Lagos Branch",
        "country": "Nigeria",
        "state": "Lagos",
        "lga": "Lagos Island",
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z",
        "created_by": "uuid",
        "profiles": {
          "id": "uuid",
          "full_name": "John Doe",
          "email": "john@example.com"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 5,
      "totalPages": 1,
      "hasNext": false,
      "hasPrev": false
    }
  }
}
```

### 3. Create Branch
```http
POST /functions/v1/manage-branches/organization/{organization_id}
```

**Authorization**: Super Admin or Organization Admin

**Path Parameters**:
- `organization_id`: UUID of the organization

**Request Body**:
```json
{
  "name": "Abuja Branch",
  "country": "Nigeria",
  "state": "FCT",
  "lga": "Abuja Municipal"
}
```

**Required Fields**:
- `name`: Branch name (max 100 characters)

**Optional Fields**:
- `country`: Country (default: "Nigeria", max 50 characters)
- `state`: State (max 50 characters)
- `lga`: Local Government Area (max 50 characters)

**Response**:
```json
{
  "success": true,
  "message": "Branch created successfully",
  "data": {
    "branch": {
      "id": "uuid",
      "organization_id": "uuid",
      "name": "Abuja Branch",
      "country": "Nigeria",
      "state": "FCT",
      "lga": "Abuja Municipal",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "created_by": "uuid",
      "organizations": {
        "id": "uuid",
        "name": "ACSL Organization",
        "partner_email": "partner@acsl.com"
      },
      "profiles": {
        "id": "uuid",
        "full_name": "John Doe",
        "email": "john@example.com"
      }
    }
  }
}
```

### 4. Get Single Branch
```http
GET /functions/v1/manage-branches/{branch_id}
```

**Authorization**: Super Admin, Organization Admin, or Agent (for their organization)

**Path Parameters**:
- `branch_id`: UUID of the branch

**Response**:
```json
{
  "success": true,
  "message": "Branch fetched successfully",
  "data": {
    "branch": {
      "id": "uuid",
      "organization_id": "uuid",
      "name": "Lagos Branch",
      "country": "Nigeria",
      "state": "Lagos",
      "lga": "Lagos Island",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z",
      "created_by": "uuid",
      "organizations": {
        "id": "uuid",
        "name": "ACSL Organization",
        "partner_email": "partner@acsl.com"
      },
      "profiles": {
        "id": "uuid",
        "full_name": "John Doe",
        "email": "john@example.com"
      }
    }
  }
}
```

### 5. Update Branch
```http
PUT /functions/v1/manage-branches/{branch_id}
PATCH /functions/v1/manage-branches/{branch_id}
```

**Authorization**: Super Admin or Organization Admin

**Path Parameters**:
- `branch_id`: UUID of the branch

**Request Body** (all fields optional):
```json
{
  "name": "Updated Branch Name",
  "country": "Nigeria",
  "state": "Updated State",
  "lga": "Updated LGA"
}
```

**Response**:
```json
{
  "success": true,
  "message": "Branch updated successfully",
  "data": {
    "branch": {
      "id": "uuid",
      "organization_id": "uuid",
      "name": "Updated Branch Name",
      "country": "Nigeria",
      "state": "Updated State",
      "lga": "Updated LGA",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T01:00:00Z",
      "created_by": "uuid",
      "organizations": {
        "id": "uuid",
        "name": "ACSL Organization",
        "partner_email": "partner@acsl.com"
      },
      "profiles": {
        "id": "uuid",
        "full_name": "John Doe",
        "email": "john@example.com"
      }
    }
  }
}
```

### 6. Delete Branch
```http
DELETE /functions/v1/manage-branches/{branch_id}
```

**Authorization**: Super Admin or Organization Admin

**Path Parameters**:
- `branch_id`: UUID of the branch

**Response**:
```json
{
  "success": true,
  "message": "Branch deleted successfully",
  "data": {
    "deletedBranch": {
      "id": "uuid",
      "name": "Deleted Branch Name",
      "organization": {
        "id": "uuid",
        "name": "ACSL Organization",
        "partner_email": "partner@acsl.com"
      }
    }
  }
}
```

## Error Responses

### 400 Bad Request
```json
{
  "success": false,
  "message": "Validation failed: name is required and must be a non-empty string"
}
```

### 401 Unauthorized
```json
{
  "success": false,
  "message": "Unauthorized: Invalid or missing authentication token"
}
```

### 403 Forbidden
```json
{
  "success": false,
  "message": "Unauthorized: You can only access branches from your organization"
}
```

### 404 Not Found
```json
{
  "success": false,
  "message": "Branch not found"
}
```

### 409 Conflict
```json
{
  "success": false,
  "message": "Branch with name \"Lagos Branch\" already exists in this organization"
}
```

### 500 Internal Server Error
```json
{
  "success": false,
  "message": "Internal server error",
  "error": "Detailed error message"
}
```

## Usage Examples

### Create a branch using cURL
```bash
curl -X POST \
  "https://your-project.supabase.co/functions/v1/manage-branches/organization/123e4567-e89b-12d3-a456-426614174000" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Kano Branch",
    "country": "Nigeria",
    "state": "Kano",
    "lga": "Kano Municipal"
  }'
```

### Get organization branches with filtering
```bash
curl -X GET \
  "https://your-project.supabase.co/functions/v1/manage-branches/organization/123e4567-e89b-12d3-a456-426614174000?page=1&limit=5&search=lagos&state=Lagos" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Update a branch
```bash
curl -X PATCH \
  "https://your-project.supabase.co/functions/v1/manage-branches/123e4567-e89b-12d3-a456-426614174000" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "state": "Updated State",
    "lga": "Updated LGA"
  }'
```

## Database Schema

The branch management system uses the `organization_branches` table with the following structure:

- `id`: Primary key (UUID)
- `organization_id`: Foreign key to organizations table (UUID, required)
- `name`: Branch name (text, required, max 100 chars)
- `country`: Country (text, default "Nigeria", max 50 chars)
- `state`: State (text, optional, max 50 chars)
- `lga`: Local Government Area (text, optional, max 50 chars)
- `created_at`: Creation timestamp
- `updated_at`: Last update timestamp (auto-updated)
- `created_by`: Foreign key to auth.users (UUID, required)

## Row Level Security (RLS)

The table has RLS enabled with the following policies:
- Super admins have full access to all branches
- Organization admins can manage their organization's branches
- Agents have read-only access to their organization's branches

## Constraints

- Branch names must be unique within each organization
- Organization ID and created_by are required fields
- Cascade delete when organization is deleted
- Restrict delete when creator user is deleted
