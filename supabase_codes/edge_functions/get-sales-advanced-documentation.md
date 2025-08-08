# Advanced Sales Data API Documentation

## Overview

This endpoint provides comprehensive sales data retrieval with extensive filtering, sorting, pagination, and export capabilities. **Only super-admin users can access this endpoint.**

## Endpoint

```
POST/GET https://your-supabase-project.supabase.co/functions/v1/get-sales-advanced
```

## Authentication

- **Required**: Bearer token in Authorization header
- **Role**: super_admin only
- **Header**: `Authorization: Bearer <supabase_jwt_token>`

## Request Methods

- **POST**: Send filters in request body (recommended for complex filters)
- **GET**: Send filters as URL parameters (for simple queries)

---

## Filter Parameters

### 📅 Date Filters

| Parameter       | Type         | Description                  | Example                  |
| --------------- | ------------ | ---------------------------- | ------------------------ |
| `dateFrom`      | string (ISO) | Filter sales from this date  | `"2024-01-01"`           |
| `dateTo`        | string (ISO) | Filter sales until this date | `"2024-12-31"`           |
| `createdFrom`   | string (ISO) | Filter by creation date from | `"2024-01-01T00:00:00Z"` |
| `createdTo`     | string (ISO) | Filter by creation date to   | `"2024-12-31T23:59:59Z"` |
| `salesDateFrom` | string (ISO) | Filter by sales date from    | `"2024-01-01"`           |
| `salesDateTo`   | string (ISO) | Filter by sales date to      | `"2024-12-31"`           |

### ⚡ Quick Date Filters

| Parameter   | Type    | Description                  | Example |
| ----------- | ------- | ---------------------------- | ------- |
| `lastNDays` | number  | Get sales from last N days   | `30`    |
| `thisWeek`  | boolean | Get sales from current week  | `true`  |
| `thisMonth` | boolean | Get sales from current month | `true`  |
| `thisYear`  | boolean | Get sales from current year  | `true`  |
| `lastWeek`  | boolean | Get sales from last week     | `true`  |
| `lastMonth` | boolean | Get sales from last month    | `true`  |
| `lastYear`  | boolean | Get sales from last year     | `true`  |

### 📍 Location Filters

| Parameter | Type     | Description               | Example                        |
| --------- | -------- | ------------------------- | ------------------------------ |
| `state`   | string   | Filter by single state    | `"Lagos"`                      |
| `states`  | string[] | Filter by multiple states | `["Lagos", "Abuja", "Kano"]`   |
| `city`    | string   | Filter by city            | `"Ikeja"`                      |
| `cities`  | string[] | Filter by multiple cities | `["Ikeja", "Victoria Island"]` |
| `lga`     | string   | Filter by LGA             | `"Ikeja"`                      |
| `lgas`    | string[] | Filter by multiple LGAs   | `["Ikeja", "Surulere"]`        |
| `country` | string   | Filter by country         | `"Nigeria"`                    |

### 🔧 Product/Stove Filters

| Parameter              | Type     | Description                   | Example                              |
| ---------------------- | -------- | ----------------------------- | ------------------------------------ |
| `stoveSerialNo`        | string   | Exact stove serial number     | `"STV001"`                           |
| `stoveSerialNos`       | string[] | Multiple stove serial numbers | `["STV001", "STV002"]`               |
| `stoveSerialNoPattern` | string   | Pattern matching (LIKE)       | `"STV"` (finds STV001, STV002, etc.) |

### 👥 People Filters

| Parameter       | Type          | Description                         | Example              |
| --------------- | ------------- | ----------------------------------- | -------------------- |
| `contactPerson` | string        | Contact person name (partial match) | `"John"`             |
| `contactPhone`  | string        | Contact phone (exact match)         | `"+2348012345678"`   |
| `endUserName`   | string        | End user name (partial match)       | `"Jane"`             |
| `aka`           | string        | Also known as (partial match)       | `"JJ"`               |
| `partnerName`   | string        | Partner name (partial match)        | `"ACSL"`             |
| `createdBy`     | string (UUID) | Created by specific user ID         | `"user-uuid-here"`   |
| `createdByIds`  | string[]      | Created by multiple users           | `["uuid1", "uuid2"]` |

### 💰 Amount Filters

| Parameter     | Type   | Description    | Example                       |
| ------------- | ------ | -------------- | ----------------------------- |
| `amountMin`   | number | Minimum amount | `1000`                        |
| `amountMax`   | number | Maximum amount | `50000`                       |
| `amountExact` | number | Exact amount   | `25000`                       |
| `amountRange` | object | Amount range   | `{"min": 1000, "max": 50000}` |

### 📊 Status Filters

| Parameter  | Type     | Description       | Example                    |
| ---------- | -------- | ----------------- | -------------------------- |
| `status`   | string   | Single status     | `"completed"`              |
| `statuses` | string[] | Multiple statuses | `["pending", "completed"]` |

### 🏢 Organization Filters

| Parameter         | Type          | Description            | Example            |
| ----------------- | ------------- | ---------------------- | ------------------ |
| `organizationId`  | string (UUID) | Single organization    | `"org-uuid-here"`  |
| `organizationIds` | string[]      | Multiple organizations | `["org1", "org2"]` |

### 📱 Phone Filters

| Parameter    | Type   | Description                 | Example            |
| ------------ | ------ | --------------------------- | ------------------ |
| `phone`      | string | Primary phone               | `"+2348012345678"` |
| `otherPhone` | string | Secondary phone             | `"+2348087654321"` |
| `anyPhone`   | string | Search in both phone fields | `"+2348012345678"` |

### 🔍 Search Filters

| Parameter      | Type     | Description                           | Example                               |
| -------------- | -------- | ------------------------------------- | ------------------------------------- |
| `search`       | string   | General search across multiple fields | `"John"`                              |
| `searchFields` | string[] | Specific fields to search in          | `["contact_person", "end_user_name"]` |

### ✅ Advanced Filters

| Parameter           | Type    | Description                        | Example |
| ------------------- | ------- | ---------------------------------- | ------- |
| `hasStoveImage`     | boolean | Filter by stove image presence     | `true`  |
| `hasAgreementImage` | boolean | Filter by agreement image presence | `true`  |
| `hasSignature`      | boolean | Filter by signature presence       | `true`  |
| `hasAddress`        | boolean | Filter by address presence         | `true`  |

### 🌍 Geolocation Filters

| Parameter      | Type   | Description                | Example                                                     |
| -------------- | ------ | -------------------------- | ----------------------------------------------------------- |
| `nearLocation` | object | Find sales near a location | `{"latitude": 6.5244, "longitude": 3.3792, "radiusKm": 10}` |

### 📄 Pagination

| Parameter | Type   | Description                 | Example | Default |
| --------- | ------ | --------------------------- | ------- | ------- |
| `page`    | number | Page number                 | `1`     | `1`     |
| `limit`   | number | Records per page (max 1000) | `50`    | `100`   |
| `offset`  | number | Skip records                | `0`     | `0`     |

### 🔄 Sorting

| Parameter   | Type     | Description            | Example                                                                           |
| ----------- | -------- | ---------------------- | --------------------------------------------------------------------------------- |
| `sortBy`    | string   | Field to sort by       | `"created_at"`                                                                    |
| `sortOrder` | string   | Sort direction         | `"desc"` or `"asc"`                                                               |
| `multiSort` | object[] | Multiple sort criteria | `[{"field": "amount", "order": "desc"}, {"field": "created_at", "order": "asc"}]` |

### 📤 Export Options

| Parameter      | Type     | Description               | Example                                             |
| -------------- | -------- | ------------------------- | --------------------------------------------------- |
| `export`       | string   | Export format             | `"csv"`, `"json"`, `"xlsx"`                         |
| `exportFields` | string[] | Specific fields to export | `["id", "stove_serial_no", "amount", "created_at"]` |

### 📋 Data Inclusion Options

| Parameter             | Type    | Description                  | Example |
| --------------------- | ------- | ---------------------------- | ------- |
| `includeAddress`      | boolean | Include address details      | `true`  |
| `includeImages`       | boolean | Include image details        | `true`  |
| `includeCreator`      | boolean | Include creator profile      | `true`  |
| `includeOrganization` | boolean | Include organization details | `true`  |
| `includeSalesHistory` | boolean | Include sales history        | `true`  |

### 📈 Advanced Date Queries

| Parameter     | Type   | Description                 | Example      |
| ------------- | ------ | --------------------------- | ------------ |
| `dayOfWeek`   | number | Filter by day of week (0-6) | `1` (Monday) |
| `monthOfYear` | number | Filter by month (1-12)      | `6` (June)   |
| `quarter`     | number | Filter by quarter (1-4)     | `2` (Q2)     |

---

## Example Requests

### 1. Simple GET Request

```javascript
const response = await fetch(
  "https://your-project.supabase.co/functions/v1/get-sales-advanced?state=Lagos&limit=50&sortBy=created_at&sortOrder=desc",
  {
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  }
);
```

### 2. Complex POST Request

```javascript
const filters = {
  // Date range
  dateFrom: "2024-01-01",
  dateTo: "2024-12-31",

  // Location
  states: ["Lagos", "Abuja", "Kano"],

  // Amount range
  amountMin: 5000,
  amountMax: 100000,

  // Search
  search: "John",

  // Boolean filters
  hasStoveImage: true,
  hasSignature: true,

  // Include related data
  includeAddress: true,
  includeCreator: true,
  includeOrganization: true,

  // Pagination
  page: 1,
  limit: 100,

  // Sorting
  multiSort: [
    { field: "amount", order: "desc" },
    { field: "created_at", order: "asc" },
  ],

  // Export (optional)
  export: "csv",
  exportFields: [
    "id",
    "stove_serial_no",
    "end_user_name",
    "amount",
    "created_at",
  ],
};

const response = await fetch(
  "https://your-project.supabase.co/functions/v1/get-sales-advanced",
  {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(filters),
  }
);
```

### 3. Export Request

```javascript
const exportFilters = {
  states: ["Lagos", "Abuja"],
  amountMin: 10000,
  export: "csv",
  exportFields: [
    "stove_serial_no",
    "end_user_name",
    "amount",
    "sales_date",
    "state_backup",
  ],
};

const response = await fetch(
  "https://your-project.supabase.co/functions/v1/get-sales-advanced",
  {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(exportFilters),
  }
);

// For CSV export, the response will be CSV content
if (exportFilters.export === "csv") {
  const csvContent = await response.text();
  // Handle CSV download
}
```

---

## Response Format

### Success Response (JSON)

```javascript
{
  "success": true,
  "data": [
    {
      "id": "uuid-here",
      "transaction_id": "TXN001",
      "stove_serial_no": "STV001",
      "sales_date": "2024-08-01",
      "contact_person": "John Doe",
      "contact_phone": "+2348012345678",
      "end_user_name": "Jane Smith",
      "aka": "JS",
      "state_backup": "Lagos",
      "lga_backup": "Ikeja",
      "phone": "+2348012345678",
      "other_phone": "+2348087654321",
      "partner_name": "ACSL",
      "amount": 25000,
      "signature": "signature_data",
      "status": "completed",
      "created_by": "creator-uuid",
      "organization_id": "org-uuid",
      "address_id": "address-uuid",
      "stove_image_id": "image-uuid",
      "agreement_image_id": "image-uuid",
      "created_at": "2024-08-01T10:00:00Z",

      // Included data (when requested)
      "address": {
        "id": "address-uuid",
        "city": "Lagos",
        "state": "Lagos",
        "street": "Allen Avenue",
        "country": "Nigeria",
        "latitude": 6.5244,
        "longitude": 3.3792,
        "full_address": "123 Allen Avenue, Ikeja, Lagos",
        "created_at": "2024-08-01T10:00:00Z"
      },
      "stove_image": {
        "id": "image-uuid",
        "url": "https://example.com/image.jpg",
        "type": "stove",
        "public_id": "cloudinary_id",
        "created_at": "2024-08-01T10:00:00Z"
      },
      "agreement_image": {
        "id": "image-uuid",
        "url": "https://example.com/agreement.jpg",
        "type": "agreement",
        "public_id": "cloudinary_id",
        "created_at": "2024-08-01T10:00:00Z"
      },
      "creator": {
        "id": "creator-uuid",
        "full_name": "Agent Name",
        "email": "agent@example.com",
        "phone": "+2348012345678",
        "role": "agent"
      },
      "organization": {
        "id": "org-uuid",
        "name": "ACSL Lagos",
        "type": "branch",
        "address": "Lagos Office",
        "contact_info": {...}
      },
      "sales_history": [
        {
          "id": "history-uuid",
          "action_type": "created",
          "action_description": "Sale created",
          "field_changes": {},
          "performed_at": "2024-08-01T10:00:00Z",
          "performed_by": "user-uuid"
        }
      ]
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 100,
    "offset": 0,
    "total": 1500,
    "totalPages": 15
  },
  "filters": {
    // Echo of applied filters
  },
  "timestamp": "2024-08-02T15:30:00Z"
}
```

### Error Responses

#### 401 Unauthorized

```javascript
{
  "success": false,
  "message": "Unauthorized"
}
```

#### 403 Forbidden

```javascript
{
  "success": false,
  "message": "Access denied. Super admin role required."
}
```

#### 404 Not Found

```javascript
{
  "success": false,
  "message": "Profile not found"
}
```

#### 500 Server Error

```javascript
{
  "success": false,
  "message": "Database query failed",
  "error": "Detailed error message"
}
```

---

## Available Fields for Filtering/Sorting

### Main Sales Fields

- `id` - UUID primary key
- `transaction_id` - Transaction identifier
- `stove_serial_no` - Stove serial number
- `sales_date` - Date of sale
- `contact_person` - Contact person name
- `contact_phone` - Contact phone number
- `end_user_name` - End user name
- `aka` - Also known as
- `state_backup` - State backup
- `lga_backup` - LGA backup
- `phone` - Primary phone
- `other_phone` - Secondary phone
- `partner_name` - Partner name
- `amount` - Sale amount
- `signature` - Digital signature
- `status` - Sale status
- `created_by` - Creator user ID
- `organization_id` - Organization ID
- `address_id` - Address ID
- `stove_image_id` - Stove image ID
- `agreement_image_id` - Agreement image ID
- `created_at` - Creation timestamp

### Related Fields (when included)

- `address.*` - Address fields
- `stove_image.*` - Stove image fields
- `agreement_image.*` - Agreement image fields
- `creator.*` - Creator profile fields
- `organization.*` - Organization fields
- `sales_history.*` - Sales history fields

---

## Usage Tips

1. **Performance**: Use specific filters rather than broad searches for better performance
2. **Pagination**: Always use pagination for large datasets (limit max 1000)
3. **Exports**: For large exports, consider using multiple requests with pagination
4. **Caching**: Consider caching frequently used filter combinations
5. **Date Formats**: Always use ISO 8601 format for dates
6. **Search**: Use the general `search` parameter for user-friendly search functionality

---

## Rate Limits

- **Standard**: 100 requests per minute per user
- **Large exports**: 10 requests per minute for export operations

---

## Support

For technical support or feature requests, contact the development team.
