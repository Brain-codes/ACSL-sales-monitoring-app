# External Sync API Integration Guide

## Overview

This guide explains how external applications can synchronize organization and stove ID data with the Stove Transaction System. The system provides two endpoints that are secure and flexible for different integration needs.

## 🔐 Getting Started

### Step 1: Get Your API Credentials

Before you can use the sync API, you need to obtain your credentials:

1. **Contact the system administrator** to request access
2. **Provide your application details**:
   - Application name
   - Description of what your app does
   - The website URLs where you'll be making API calls from
3. **Receive your credentials**:
   - `token`: Your unique application token
   - `secret_key`: Your secret key for authentication
   - `application_name`: The registered name of your application

### Step 2: Set Up Your Environment

Replace these values in your code with your actual credentials:

- `YOUR_TOKEN_HERE` → Your actual token
- `YOUR_SECRET_HERE` → Your actual secret key
- `YOUR_APP_NAME` → Your registered application name
- `https://your-project-id.supabase.co/functions/v1` → The actual API base URL

## 📡 API Endpoints

### Endpoint 1: Single Organization Sync

**URL**: `/external-sync`
**Purpose**: Sync one organization at a time with optional stove IDs

### Endpoint 2: CSV Bulk Sync

**URL**: `/external-csv-sync`  
**Purpose**: Sync multiple organizations using CSV data

## 🔧 How to Use Each Endpoint

### Single Organization Sync

**When to use**: When you want to sync one organization at a time, typically triggered by user actions in your app.

**Example**: User clicks "Send to Stove System" button for a specific partner.

**Required Information**:

- Partner ID (unique identifier)
- Partner Name
- Your authentication credentials

**Optional Information**:

- Email address
- Contact person name
- Phone numbers
- Address
- State/Region
- Branch/Office name
- List of stove IDs

**How to call the API**:

```javascript
// JavaScript/TypeScript example
const response = await fetch(
  "https://your-project-id.supabase.co/functions/v1/external-sync",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      token: "YOUR_TOKEN_HERE",
      secret_key: "YOUR_SECRET_HERE",
      application_name: "YOUR_APP_NAME",
      organization_data: {
        partner_id: "ACME001",
        partner_name: "ACME Corporation",
        email: "contact@acme.com",
        contact_person: "John Smith",
        contact_phone: "+1234567890",
        address: "123 Business Street",
        state: "California",
      },
      stove_ids: ["STV001", "STV002", "STV003"],
      origin_url: "https://your-app.com",
    }),
  }
);

const result = await response.json();
if (result.success) {
  console.log("Sync successful!", result.data);
} else {
  console.error("Sync failed:", result.message);
}
```

### CSV Bulk Sync

**When to use**: When you want to sync many organizations at once, typically for batch operations or scheduled syncs.

**Example**: Nightly sync of all updated partners from your system.

**CSV Format Requirements**:

- **Must have**: `partner_id` and `partner_name` columns
- **Can have**: Any of the optional fields in any order
- **Extra columns**: Are allowed and will be ignored
- **Different names**: The system can understand common variations

**Supported Column Names**:

- Partner ID: `partner_id`, `partnerid`, `partner_code`, `id`, `code`
- Partner Name: `partner_name`, `partnername`, `name`, `organization_name`
- Email: `email`, `email_address`, `partner_email`
- Contact Person: `contact_person`, `contactperson`, `contact_name`
- Phone: `contact_phone`, `phone`, `primary_phone`
- Address: `address`, `full_address`, `location`
- State: `state`, `region`, `province`
- Stove IDs: `stove_ids`, `stoveids`, `serial_numbers` (separate multiple IDs with semicolons)

**How to call the API**:

```javascript
// Prepare your CSV data as a string
const csvData = `partner_id,partner_name,email,contact_phone,stove_ids
ACME001,ACME Corporation,contact@acme.com,+1234567890,STV001;STV002
TECH002,Tech Solutions,info@tech.com,+1987654321,STV003;STV004`;

const response = await fetch(
  "https://your-project-id.supabase.co/functions/v1/external-csv-sync",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      token: "YOUR_TOKEN_HERE",
      secret_key: "YOUR_SECRET_HERE",
      application_name: "YOUR_APP_NAME",
      csv_data: csvData,
      origin_url: "https://your-app.com",
    }),
  }
);
```

## 🛡️ Security Features

### Token-Based Authentication

- Each request must include your `token`, `secret_key`, and `application_name`
- All three must match exactly for the request to be accepted
- Tokens can be deactivated if compromised

### URL Validation

- Your application URLs are validated against an allowed list
- This prevents unauthorized usage from other websites
- Contact the administrator to update your allowed URLs

### Usage Tracking

- Every API call is logged and counted
- Administrators can monitor usage patterns
- Helps detect unusual activity

## 📊 Understanding API Responses

### Success Response

```json
{
  "success": true,
  "message": "Organization data synchronized successfully",
  "data": {
    "organization": {
      "id": "uuid-here",
      "partner_id": "ACME001",
      "partner_name": "ACME Corporation",
      "action": "created" // or "updated"
    },
    "stove_ids": [
      { "stove_id": "STV001", "action": "created" },
      { "stove_id": "STV002", "action": "already_exists" }
    ],
    "summary": {
      "organization_action": "created",
      "stove_ids_processed": 2,
      "stove_ids_created": 1,
      "stove_ids_skipped": 1
    }
  }
}
```

### Error Response

```json
{
  "success": false,
  "message": "Invalid token, secret key, or application name"
}
```

## 🚨 Common Issues and Solutions

### Issue: "Invalid authentication credentials"

**Solution**: Check that your `token`, `secret_key`, and `application_name` are correct and haven't been changed.

### Issue: "Request origin not allowed"

**Solution**: Contact the administrator to add your website URL to the allowed list.

### Issue: "Required field 'partner_id' not found"

**Solution**: Make sure your CSV has a column that can be recognized as partner ID (see supported column names above).

### Issue: "No valid organization data found in CSV"

**Solution**: Check that your CSV has at least one row with valid `partner_id` and `partner_name` values.

## 📋 Testing Your Integration

### Using Postman

1. Import the provided Postman collection: `External_Sync_API_Postman_Collection.json`
2. Update the variables with your actual credentials
3. Test each endpoint to ensure they work correctly

### Testing Steps

1. **Test authentication**: Try with invalid credentials to ensure security works
2. **Test single sync**: Create one organization to verify the basic flow
3. **Test CSV sync**: Upload a small CSV file to verify bulk operations
4. **Test error handling**: Intentionally send bad data to test error responses

## 💡 Best Practices

### For React/TypeScript Applications

```typescript
// Create a service class for API calls
class StoveTransactionSync {
  private readonly baseUrl = "https://your-project-id.supabase.co/functions/v1";
  private readonly credentials = {
    token: process.env.REACT_APP_STOVE_TOKEN!,
    secret_key: process.env.REACT_APP_STOVE_SECRET!,
    application_name: process.env.REACT_APP_STOVE_APP_NAME!,
  };

  async syncOrganization(organizationData: any, stoveIds?: string[]) {
    try {
      const response = await fetch(`${this.baseUrl}/external-sync`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          ...this.credentials,
          organization_data: organizationData,
          stove_ids: stoveIds,
          origin_url: window.location.origin,
        }),
      });

      const result = await response.json();
      if (!result.success) {
        throw new Error(result.message);
      }
      return result.data;
    } catch (error) {
      console.error("Sync failed:", error);
      throw error;
    }
  }

  async syncCSV(csvData: string) {
    // Similar implementation for CSV sync
  }
}
```

### Environment Variables

Store your credentials in environment variables, never in your code:

```
REACT_APP_STOVE_TOKEN=your_token_here
REACT_APP_STOVE_SECRET=your_secret_here
REACT_APP_STOVE_APP_NAME=your_app_name
```

### Error Handling

Always handle both network errors and API errors:

```javascript
try {
  const result = await syncService.syncOrganization(data);
  // Handle success
  showSuccessMessage("Organization synced successfully!");
} catch (error) {
  // Handle error
  showErrorMessage(`Sync failed: ${error.message}`);
}
```

### Rate Limiting

- Don't make too many requests at once
- Consider adding delays between batch operations
- Monitor your usage through the administrator

## 📞 Support and Contact

If you encounter issues or need help:

1. **Check this documentation** first for common solutions
2. **Test with Postman** to isolate the issue
3. **Contact the system administrator** with:
   - Your application name
   - Description of the issue
   - Example request data that's failing
   - Error messages you're receiving

## 🔄 API Updates

This API may be updated over time. Changes will be:

- **Backward compatible** whenever possible
- **Announced in advance** for breaking changes
- **Documented** with migration guides when needed

Keep your integration code flexible to handle minor response format changes.

---

**Last Updated**: October 2025  
**API Version**: 1.0.0
