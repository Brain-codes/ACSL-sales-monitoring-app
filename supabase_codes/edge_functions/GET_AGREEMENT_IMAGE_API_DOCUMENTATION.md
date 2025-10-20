# User Agreement Image API Endpoint

## Overview

This endpoint allows you to query user agreement images by stove serial number and retrieve either the raw binary file or detailed metadata about the image and associated sale.

## Endpoint Details

**URL**: `/functions/v1/get-agreement-image-by-serial`  
**Method**: `GET`  
**Authentication**: Required (Bearer Token)

## Query Parameters

| Parameter       | Type   | Required | Default  | Description                           |
| --------------- | ------ | -------- | -------- | ------------------------------------- |
| `serial_number` | string | ✅ Yes   | -        | The stove serial number to search for |
| `return_type`   | string | ❌ No    | `binary` | Response type: `binary` or `details`  |

### Return Type Options

- **`binary`**: Returns the raw image file as binary data
- **`details`**: Returns JSON metadata about the image and sale

## Request Headers

```
Authorization: Bearer <your-supabase-jwt-token>
Content-Type: application/json (for details response)
```

## Usage Examples

### 1. Get Raw Binary Image File

```bash
curl -X GET \
  "https://your-project.supabase.co/functions/v1/get-agreement-image-by-serial?serial_number=SN123456789" \
  -H "Authorization: Bearer <your-jwt-token>" \
  --output agreement_image.jpg
```

```javascript
// JavaScript/TypeScript
const response = await fetch(
  `https://your-project.supabase.co/functions/v1/get-agreement-image-by-serial?serial_number=SN123456789`,
  {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  }
);

if (response.ok) {
  const imageBlob = await response.blob();
  // Use the image blob as needed
  const imageUrl = URL.createObjectURL(imageBlob);
} else {
  const error = await response.json();
  console.error("Error:", error.message);
}
```

### 2. Get Image Details and Metadata

```bash
curl -X GET \
  "https://your-project.supabase.co/functions/v1/get-agreement-image-by-serial?serial_number=SN123456789&return_type=details" \
  -H "Authorization: Bearer <your-jwt-token>"
```

```javascript
// JavaScript/TypeScript
const response = await fetch(
  `https://your-project.supabase.co/functions/v1/get-agreement-image-by-serial?serial_number=SN123456789&return_type=details`,
  {
    headers: {
      Authorization: `Bearer ${token}`,
    },
  }
);

const result = await response.json();
console.log(result.data);
```

## Response Formats

### Binary Response (return_type=binary)

- **Content-Type**: `image/jpeg`, `image/png`, `image/gif`, etc. (based on actual file type)
- **Body**: Raw binary image data
- **Headers**:
  - `Content-Disposition`: `inline; filename="agreement_{serial_number}.{ext}"`
  - `Cache-Control`: `public, max-age=3600`
  - `X-Serial-Number`: The queried serial number
  - `X-Upload-ID`: The internal upload ID

### Details Response (return_type=details)

```json
{
  "success": true,
  "message": "Agreement image details retrieved successfully",
  "data": {
    "sale": {
      "id": "uuid",
      "stove_serial_no": "SN123456789",
      "sales_date": "2024-01-15",
      "contact_person": "John Doe",
      "end_user_name": "Jane Smith",
      "partner_name": "Partner Company",
      "status": "completed"
    },
    "image": {
      "id": "uuid",
      "public_id": "uuid",
      "url": "https://...",
      "type": "image/jpeg",
      "created_at": "2024-01-15T10:30:00Z"
    }
  }
}
```

## Error Responses

### 400 - Missing Serial Number

```json
{
  "success": false,
  "message": "Missing required parameter: serial_number"
}
```

### 401 - Unauthorized

```json
{
  "success": false,
  "message": "Unauthorized"
}
```

### 404 - Image Not Found

```json
{
  "success": false,
  "message": "No agreement image found for serial number: SN123456789"
}
```

### 405 - Method Not Allowed

```json
{
  "success": false,
  "message": "Method not allowed. Use GET."
}
```

### 500 - Server Error

```json
{
  "success": false,
  "message": "Unexpected error occurred",
  "error": "Error details..."
}
```

## TypeScript Types

```typescript
// Request types
interface GetAgreementImageParams {
  serial_number: string;
  return_type?: "binary" | "details";
}

// Response types for details endpoint
interface AgreementImageDetailsResponse {
  success: boolean;
  message: string;
  data: {
    sale: {
      id: string;
      stove_serial_no: string;
      sales_date: string;
      contact_person: string;
      end_user_name: string;
      partner_name: string;
      status: "incomplete" | "pending" | "completed" | "assigned";
    };
    image: {
      id: string;
      public_id: string;
      url: string;
      type: string;
      created_at: string;
    };
  };
}

interface ErrorResponse {
  success: false;
  message: string;
  error?: string;
}

// Usage example with types
async function getAgreementImage(
  serialNumber: string,
  returnType: "binary" | "details" = "binary"
): Promise<Blob | AgreementImageDetailsResponse> {
  const params = new URLSearchParams({
    serial_number: serialNumber,
    return_type: returnType,
  });

  const response = await fetch(
    `https://your-project.supabase.co/functions/v1/get-agreement-image-by-serial?${params}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }
  );

  if (!response.ok) {
    const error: ErrorResponse = await response.json();
    throw new Error(error.message);
  }

  if (returnType === "binary") {
    return response.blob();
  } else {
    return response.json() as Promise<AgreementImageDetailsResponse>;
  }
}
```

## Security Notes

1. **Authentication Required**: All requests must include a valid Supabase JWT token
2. **Row Level Security**: Users can only access images from sales within their organization
3. **CORS Enabled**: The endpoint supports cross-origin requests
4. **File Type Validation**: Only returns images that exist in the database and storage

## Rate Limiting

- Standard Supabase Edge Function rate limits apply
- Consider implementing client-side caching for frequently accessed images
- Images are served with 1-hour cache headers to reduce server load

## Integration Examples

### React/Next.js Component

```jsx
import { useState } from "react";

function AgreementImageViewer({ serialNumber, token }) {
  const [imageUrl, setImageUrl] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const loadImage = async () => {
    setLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `https://your-project.supabase.co/functions/v1/get-agreement-image-by-serial?serial_number=${serialNumber}`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        }
      );

      if (response.ok) {
        const blob = await response.blob();
        const url = URL.createObjectURL(blob);
        setImageUrl(url);
      } else {
        const errorData = await response.json();
        setError(errorData.message);
      }
    } catch (err) {
      setError("Failed to load image");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <button onClick={loadImage} disabled={loading}>
        {loading ? "Loading..." : "Load Agreement Image"}
      </button>

      {error && <p style={{ color: "red" }}>Error: {error}</p>}

      {imageUrl && (
        <img
          src={imageUrl}
          alt={`Agreement for ${serialNumber}`}
          style={{ maxWidth: "100%", height: "auto" }}
        />
      )}
    </div>
  );
}
```

### Flutter/Dart Implementation

```dart
import 'dart:io';
import 'package:http/http.dart' as http;

class AgreementImageService {
  final String baseUrl;
  final String token;

  AgreementImageService({required this.baseUrl, required this.token});

  Future<List<int>?> getAgreementImageBinary(String serialNumber) async {
    final uri = Uri.parse('$baseUrl/functions/v1/get-agreement-image-by-serial')
        .replace(queryParameters: {'serial_number': serialNumber});

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print('Error: ${response.body}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAgreementImageDetails(String serialNumber) async {
    final uri = Uri.parse('$baseUrl/functions/v1/get-agreement-image-by-serial')
        .replace(queryParameters: {
          'serial_number': serialNumber,
          'return_type': 'details'
        });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('Error: ${response.body}');
      return null;
    }
  }
}
```

## Deployment Instructions

1. Save the edge function as `get-agreement-image-by-serial.ts` in your Supabase project
2. Deploy using the Supabase CLI:
   ```bash
   supabase functions deploy get-agreement-image-by-serial
   ```
3. Ensure your Row Level Security policies allow access to the `sales` and `uploads` tables
4. Test the endpoint with a valid serial number and authentication token

## Performance Tips

1. **Use the details endpoint first** to check if an image exists before downloading the binary
2. **Implement client-side caching** to avoid repeated downloads
3. **Consider image optimization** on the client side for display purposes
4. **Use appropriate image formats** (WebP, AVIF) when supported by your clients
