# 📋 Comprehensive Admin Flow Documentation

## 🏗️ **Application Overview**

This is a **Sales Monitoring Application** using **Supabase** as the backend. The app supports both **Admin** and **Agent** roles with offline-first capabilities.

---

## 🔐 **ADMIN AUTHENTICATION & USER FLOW**

### **Step 1: Login Process**

**Original Files**: `lib/login/ui/login_screen.dart` + `lib/login/controller/login_controller.dart`

**Flow**:

1. User enters email and password
2. System calls authentication service
3. Authenticates via **Supabase Auth** (`signInWithPassword`)
4. Fetches user metadata to determine role
5. If role is `admin`, redirects to admin dashboard

**API Endpoints Used**:

- **Supabase Auth**: `signInWithPassword()` (built-in)
- **Edge Function**: `get-user-profile` (fetches complete user profile with organization)

---

### **Step 2: Admin Layout (Navigation Container)**

**Original File**: `lib/main_layout/ui/main_layout.dart`

**Navigation Structure**:

- **Dashboard** - Main admin hub
- **Sales** - Sales management and creation
- **Agents** - Sales agent management
- **Settings** - Profile and system settings

---

### **Step 3: Dashboard Screen (Main Admin Hub)**

**Original Files**: `lib/admin/dashboard/ui/dashboard_screen.dart` + `lib/admin/dashboard/controller/dashboard_controller.dart`

**Dashboard Components**:

1. **Welcome Header** with user name
2. **Alert Banner** (shows pending sales requiring attention)
3. **Summary Cards** (Total Sales, Sales Agents, Completed Sales, etc.)
4. **Stove Progress Bar** (showing stove inventory status)
5. **Quick Action Tiles** (navigation to key features)

**API Endpoints Used**:

- **Edge Function**: `get-dashboard-stats` - fetches all dashboard statistics

**Dashboard Data Structure**:

```typescript
interface DashboardStats {
  success: boolean;
  data: {
    total_sales: number;
    sales_agents: number;
    stoves_with_landmark: number;
    completed_sales: number;
    pending_sales: number;
    total_sales_amount: number;
    total_stoves_received: number;
    total_stoves_sold: number;
    total_stoves_available: number;
  };
}
```

**Quick Actions Available**:

1. **Start New Sale** - Navigate to sale creation form
2. **Manage Sales Agents** - Navigate to agents management
3. **View All Sales** - Navigate to sales list
4. **Sync Offline Data** - Navigate to sync screen
5. **Offline Records** - Navigate to offline records

---

### **Step 4: Sales Management**

**Original Files**: `lib/admin/sales/ui/admin_sales_screen.dart`, `lib/admin/sales/ui/manage_sales_screen.dart`

#### **4.1 View All Sales**

**Features**:

- **Search** by Stove Serial No. or Transaction ID
- **Filter** by Date Range, State, LGA
- **Pagination** with infinite scroll
- **Refresh** to reload data
- **Sale Details** view for individual sales

**API Endpoints Used**:

- **Edge Function**: `get-sales-advanced` - main sales fetching with advanced filtering
- **Edge Function**: `get-sale` - individual sale details

**Sales Filter Parameters**:

```typescript
interface SalesFilters {
  search?: string;
  dateRange?: { start: Date; end: Date };
  state?: string;
  lga?: string;
  page: number;
  limit: number;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
}
```

#### **4.2 Create New Sale**

**Original Files**: `lib/form/ui/user_form.dart` + `lib/form/controller/form_controller.dart`

**Sale Creation Process**:

1. **Personal Info**: End user name, phone, partner name
2. **Location**: State, LGA, full address with GPS coordinates
3. **Stove Selection**: Choose from available stove serial numbers
4. **Amount**: Sale amount input
5. **Images**: Stove photo and agreement document
6. **Signature**: Digital signature capture
7. **Submit**: Creates sale record

**API Endpoints Used**:

- **Edge Function**: `get-stove-ids` - fetches available stove serial numbers
- **Edge Function**: `upload-image` - uploads stove and agreement images
- **Edge Function**: `create-sale` - creates the complete sale record

**Sale Creation Payload**:

```typescript
interface CreateSalePayload {
  endUserName: string;
  phone: string;
  otherPhone?: string;
  partnerName: string;
  amount: number;
  stoveSerialNo: string;
  stateBackup: string;
  lgaBackup: string;
  addressData: {
    street: string;
    city: string;
    state: string;
    country: string;
    latitude: number;
    longitude: number;
    fullAddress: string;
  };
  signature: string; // base64
  stoveImageId: string;
  agreementImageId: string;
}
```

#### **4.3 Update Sale**

**Original Files**: `lib/admin/sales/ui/update_sale_screen.dart`

**API Endpoints Used**:

- **Edge Function**: `update-sale` - updates sale information

---

### **Step 5: Sales Agent Management**

**Original Files**: `lib/admin/sub_accounts/ui/manage_sales_agents_screen.dart`

#### **5.1 View Sales Agents**

**Features**:

- List all sales agents in the organization
- View agent details
- Add new agents

**API Endpoints Used**:

- **Edge Function**: `get-sales-agents` - fetches all sales agents for the organization

#### **5.2 Add New Sales Agent**

**Process**:

1. Enter agent name and email
2. System generates random password
3. Creates user account
4. Shows modal with login credentials

**API Endpoints Used**:

- **Edge Function**: `create-agent-user` - creates new sales agent account

---

### **Step 6: Settings Screen**

**Original Files**: `lib/shared/ui/settings_screen.dart`

**Settings Options**:

1. **Profile** - View/edit user profile
2. **Security** - Password management
3. **FAQ** - Help section
4. **Chat Support** - Support contact
5. **Offline Data** - Offline mode toggle and sync
6. **Logout** - Sign out functionality

#### **6.1 Profile Management**

**Features**:

- View personal information
- Edit updateable fields (name, phone)
- Change password
- View organization details
- Account status

**API Endpoints Used**:

- **Edge Function**: `get-user-profile` - fetches complete user profile
- **Supabase Auth**: `updateUser()` - updates profile information
- **Supabase Auth**: `updateUser()` - changes password

---

## 🔗 **Complete API Endpoints Reference**

### **Authentication Endpoints**

```typescript
// Supabase Auth (built-in)
supabase.auth.signInWithPassword({ email, password })
supabase.auth.getUser()
supabase.auth.refreshSession()
supabase.auth.signOut()
supabase.auth.updateUser({ data: { ... } })
```

### **Dashboard Endpoints**

```typescript
// 1. get-dashboard-stats
interface DashboardStatsRequest {
  // No parameters - uses authenticated user's organization
}

interface DashboardStatsResponse {
  success: boolean;
  data: {
    total_sales: number;
    sales_agents: number;
    stoves_with_landmark: number;
    completed_sales: number;
    pending_sales: number;
    total_sales_amount: number;
    total_stoves_received: number;
    total_stoves_sold: number;
    total_stoves_available: number;
  };
}

// Usage
const { data } = await supabase.functions.invoke("get-dashboard-stats", {
  body: {},
});
```

### **Sales Management Endpoints**

```typescript
// 1. get-sales-advanced
interface GetSalesAdvancedRequest {
  // Filtering
  search?: string;
  stoveSerialNo?: string;
  endUserName?: string;
  partnerName?: string;
  phone?: string;

  // Date filtering
  dateFrom?: string; // ISO date
  dateTo?: string; // ISO date

  // Location filtering
  states?: string[];
  lgas?: string[];

  // Amount filtering
  amountMin?: number;
  amountMax?: number;

  // Status filtering
  statuses?: ("pending" | "completed" | "assigned" | "incomplete")[];

  // Pagination
  page?: number;
  limit?: number; // max 1000

  // Sorting
  sortBy?: "created_at" | "amount" | "stove_serial_no" | "end_user_name";
  sortOrder?: "asc" | "desc";

  // Export
  export?: "csv";
  exportFields?: string[];
}

interface GetSalesAdvancedResponse {
  success: boolean;
  data: Sale[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
    hasMore: boolean;
  };
  debug?: {
    queryResultCount: number;
    totalRecordsInTable: number;
    userRole: string;
    userId: string;
  };
}

// 2. get-sales (basic)
interface GetSalesRequest {
  query?: string;
  from?: string;
  to?: string;
  state?: string;
  lga?: string;
  page?: number;
  limit?: number;
}

// 3. get-sale (individual)
interface GetSaleRequest {
  saleId: string;
}

// 4. create-sale
interface CreateSaleRequest {
  endUserName: string;
  phone: string;
  otherPhone?: string;
  partnerName: string;
  amount: number;
  stoveSerialNo: string;
  stateBackup: string;
  lgaBackup: string;
  addressData: {
    street: string;
    city: string;
    state: string;
    country: string;
    latitude: number;
    longitude: number;
    fullAddress: string;
  };
  signature: string; // base64
  stoveImageId: string;
  agreementImageId: string;
}

// 5. update-sale
interface UpdateSaleRequest {
  saleId: string;
  // Same fields as CreateSaleRequest (partial update)
}
```

### **Stove Management Endpoints**

```typescript
// get-stove-ids
interface GetStoveIdsRequest {
  organization_id: string;
  status?: "available" | "sold";
}

interface GetStoveIdsResponse {
  success: boolean;
  data: {
    id: string;
    stove_id: string;
    status: "available" | "sold";
    created_at: string;
  }[];
  totals: {
    total_stove_ids: number;
    total_stove_available: number;
    total_stove_sold: number;
  };
}
```

### **Sales Agent Management Endpoints**

```typescript
// 1. get-sales-agents
interface GetSalesAgentsResponse {
  success: boolean;
  data: {
    id: string;
    full_name: string;
    email: string;
    role: string;
    organization_id: string;
    created_at: string;
    has_changed_password: boolean;
  }[];
}

// 2. create-agent-user
interface CreateAgentRequest {
  name: string;
  email: string;
}

interface CreateAgentResponse {
  success: boolean;
  data: {
    user: any;
    profile: any;
    generatedPassword: string;
  };
}
```

### **Profile & User Management Endpoints**

```typescript
// get-user-profile
interface GetUserProfileRequest {
  userId: string;
}

interface GetUserProfileResponse {
  success: boolean;
  data: {
    id: string;
    email: string;
    full_name: string;
    phone?: string;
    role: string;
    has_changed_password: boolean;
    created_at: string;
    organization?: {
      id: string;
      name: string;
      partner_email: string;
      created_at: string;
    };
  };
}
```

### **Image Upload Endpoints**

```typescript
// upload-image
interface UploadImageRequest {
  image: string; // base64
  filename: string;
  folder: "stove_images" | "agreement_images";
}

interface UploadImageResponse {
  success: boolean;
  data: {
    imageId: string;
    url: string;
  };
}
```

### **Activity & History Endpoints**

```typescript
// log-sales-activity
interface LogSalesActivityRequest {
  saleId: string;
  activityType: string;
  description: string;
  metadata?: any;
}

// get-sales-activities
interface GetSalesActivitiesRequest {
  saleId?: string;
  userId?: string;
  page?: number;
  limit?: number;
}
```

---

## 🗂️ **Data Models (TypeScript Interfaces)**

### **Core Models**

```typescript
interface Sale {
  id: string;
  stove_serial_no: string;
  end_user_name: string;
  phone: string;
  other_phone?: string;
  partner_name: string;
  amount: number;
  status: "pending" | "completed" | "assigned" | "incomplete";
  state_backup: string;
  lga_backup: string;
  address_id: string;
  stove_image_id: string;
  agreement_image_id: string;
  signature: string;
  created_at: string;
  updated_at: string;
  organization_id: string;
  created_by: string;

  // Related data (populated via joins)
  address?: Address;
  stove_image?: Upload;
  agreement_image?: Upload;
  creator?: Profile;
  organization?: Organization;
}

interface Address {
  id: string;
  street: string;
  city: string;
  state: string;
  country: string;
  latitude: number;
  longitude: number;
  full_address: string;
  created_at: string;
}

interface Upload {
  id: string;
  filename: string;
  url: string;
  file_size: number;
  mime_type: string;
  created_at: string;
}

interface Profile {
  id: string;
  email: string;
  full_name?: string;
  phone?: string;
  role: "admin" | "agent" | "super_admin";
  organization_id?: string;
  has_changed_password: boolean;
  created_at: string;
  updated_at: string;

  // Related data
  organization?: Organization;
}

interface Organization {
  id: string;
  name: string;
  partner_email: string;
  created_at: string;
  updated_at: string;
}

interface StoveId {
  id: string;
  stove_id: string;
  status: "available" | "sold";
  organization_id: string;
  created_at: string;
}

interface SalesActivity {
  id: string;
  sale_id: string;
  user_id: string;
  activity_type: string;
  description: string;
  metadata?: any;
  created_at: string;

  // Related data
  user?: Profile;
  sale?: Sale;
}
```

### **Request/Response Types**

```typescript
interface PaginationParams {
  page: number;
  limit: number;
}

interface PaginationResponse {
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

interface ApiResponseWithPagination<T> extends ApiResponse<T[]> {
  pagination: PaginationResponse;
}

// Filter types
interface DateRange {
  start: Date;
  end: Date;
}

interface SalesFilters extends PaginationParams {
  search?: string;
  stoveSerialNo?: string;
  endUserName?: string;
  partnerName?: string;
  phone?: string;
  dateRange?: DateRange;
  states?: string[];
  lgas?: string[];
  amountMin?: number;
  amountMax?: number;
  statuses?: Sale["status"][];
  sortBy?: keyof Sale;
  sortOrder?: "asc" | "desc";
}
```

---

This comprehensive documentation provides all the admin flow details, API endpoints, data models, and backend integration patterns needed for any frontend implementation.

---

# COMPREHENSIVE ADMIN FLOW CONTINUATION - ALL EDGE FUNCTIONS & API CALLS

This continuation provides complete documentation for all remaining admin flow features, edge functions, and API endpoints not covered in the main documentation above.

## Additional Edge Functions for Admin Flow

### 1. **Agent Management Edge Functions**

#### `create-agent` Edge Function

```typescript
interface CreateAgentRequest {
  email: string;
  password: string;
  profile: {
    firstName: string;
    lastName: string;
    phoneNumber: string;
    address?: string;
    targetAmount?: number;
    commission?: number;
  };
}

interface CreateAgentResponse {
  success: boolean;
  message: string;
  data?: {
    user: User;
    profile: Profile;
  };
}
```

**API Call:**

```
POST /functions/v1/create-agent
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: CreateAgentRequest
Response: CreateAgentResponse
```

#### `update-agent` Edge Function

```typescript
interface UpdateAgentRequest {
  agentId: string;
  profile: {
    firstName?: string;
    lastName?: string;
    phoneNumber?: string;
    address?: string;
    targetAmount?: number;
    commission?: number;
    isActive?: boolean;
  };
}
```

**API Call:**

```
POST /functions/v1/update-agent
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: UpdateAgentRequest
Response: StandardApiResponse
```

#### `deactivate-agent` Edge Function

```typescript
interface DeactivateAgentRequest {
  agentId: string;
  reason?: string;
}
```

**API Call:**

```
POST /functions/v1/deactivate-agent
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: DeactivateAgentRequest
Response: StandardApiResponse
```

#### `get-agent-performance` Edge Function

```typescript
interface AgentPerformanceRequest {
  agentId: string;
  dateFrom?: string;
  dateTo?: string;
}

interface AgentPerformanceResponse {
  success: boolean;
  data: {
    totalSales: number;
    totalAmount: number;
    commission: number;
    salesByStatus: {
      pending: number;
      confirmed: number;
      completed: number;
      cancelled: number;
    };
    monthlyPerformance: Array<{
      month: string;
      sales: number;
      amount: number;
    }>;
    targetAchievement: {
      target: number;
      achieved: number;
      percentage: number;
    };
  };
}
```

**API Call:**

```
POST /functions/v1/get-agent-performance
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: AgentPerformanceRequest
Response: AgentPerformanceResponse
```

### 2. **Sales Management Edge Functions**

#### `bulk-update-sales` Edge Function

```typescript
interface BulkUpdateSalesRequest {
  saleIds: string[];
  updates: {
    status?: Sale["status"];
    notes?: string;
    priority?: "low" | "medium" | "high";
  };
}

interface BulkUpdateSalesResponse {
  success: boolean;
  message: string;
  data: {
    updated: number;
    failed: number;
    errors?: Array<{
      saleId: string;
      error: string;
    }>;
  };
}
```

**API Call:**

```
POST /functions/v1/bulk-update-sales
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: BulkUpdateSalesRequest
Response: BulkUpdateSalesResponse
```

#### `export-sales-data` Edge Function

```typescript
interface ExportSalesRequest {
  filters: SaleFilters;
  format: "csv" | "excel" | "pdf";
  columns: string[];
}

interface ExportSalesResponse {
  success: boolean;
  data: {
    downloadUrl: string;
    filename: string;
    expiresAt: string;
  };
}
```

**API Call:**

```
POST /functions/v1/export-sales-data
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: ExportSalesRequest
Response: ExportSalesResponse
```

#### `get-sales-analytics` Edge Function

```typescript
interface SalesAnalyticsRequest {
  dateFrom: string;
  dateTo: string;
  groupBy: "day" | "week" | "month";
  agentId?: string;
}

interface SalesAnalyticsResponse {
  success: boolean;
  data: {
    totalSales: number;
    totalAmount: number;
    averageOrderValue: number;
    conversionRate: number;
    timeSeriesData: Array<{
      date: string;
      sales: number;
      amount: number;
    }>;
    topPerformingAgents: Array<{
      agentId: string;
      agentName: string;
      sales: number;
      amount: number;
    }>;
    statusDistribution: Record<Sale["status"], number>;
  };
}
```

**API Call:**

```
POST /functions/v1/get-sales-analytics
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: SalesAnalyticsRequest
Response: SalesAnalyticsResponse
```

### 3. **Commission Management Edge Functions**

#### `calculate-commissions` Edge Function

```typescript
interface CalculateCommissionsRequest {
  dateFrom: string;
  dateTo: string;
  agentIds?: string[];
}

interface CommissionData {
  agentId: string;
  agentName: string;
  totalSales: number;
  totalAmount: number;
  commissionRate: number;
  commissionAmount: number;
  bonuses: number;
  deductions: number;
  netCommission: number;
}

interface CalculateCommissionsResponse {
  success: boolean;
  data: {
    commissions: CommissionData[];
    totalCommissions: number;
    period: {
      from: string;
      to: string;
    };
  };
}
```

**API Call:**

```
POST /functions/v1/calculate-commissions
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: CalculateCommissionsRequest
Response: CalculateCommissionsResponse
```

#### `approve-commissions` Edge Function

```typescript
interface ApproveCommissionsRequest {
  commissionIds: string[];
  approvalNotes?: string;
}
```

**API Call:**

```
POST /functions/v1/approve-commissions
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: ApproveCommissionsRequest
Response: StandardApiResponse
```

### 4. **Notification Management Edge Functions**

#### `send-bulk-notification` Edge Function

```typescript
interface BulkNotificationRequest {
  recipients: {
    userIds?: string[];
    roles?: ("admin" | "agent")[];
    all?: boolean;
  };
  notification: {
    title: string;
    message: string;
    type: "info" | "warning" | "success" | "error";
    actionUrl?: string;
    expiresAt?: string;
  };
}
```

**API Call:**

```
POST /functions/v1/send-bulk-notification
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: BulkNotificationRequest
Response: StandardApiResponse
```

#### `get-notification-analytics` Edge Function

```typescript
interface NotificationAnalyticsResponse {
  success: boolean;
  data: {
    totalSent: number;
    totalRead: number;
    readRate: number;
    recentNotifications: Array<{
      id: string;
      title: string;
      sentAt: string;
      recipients: number;
      readCount: number;
    }>;
  };
}
```

**API Call:**

```
GET /functions/v1/get-notification-analytics
Authorization: Bearer <admin_token>

Response: NotificationAnalyticsResponse
```

### 5. **System Administration Edge Functions**

#### `get-system-logs` Edge Function

```typescript
interface SystemLogsRequest {
  level?: "error" | "warn" | "info" | "debug";
  dateFrom?: string;
  dateTo?: string;
  userId?: string;
  limit?: number;
  offset?: number;
}

interface SystemLog {
  id: string;
  level: string;
  message: string;
  userId?: string;
  userEmail?: string;
  action: string;
  details: Record<string, any>;
  createdAt: string;
}

interface SystemLogsResponse {
  success: boolean;
  data: {
    logs: SystemLog[];
    total: number;
    hasMore: boolean;
  };
}
```

**API Call:**

```
POST /functions/v1/get-system-logs
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: SystemLogsRequest
Response: SystemLogsResponse
```

#### `backup-database` Edge Function

```typescript
interface BackupRequest {
  tables?: string[];
  includeFiles?: boolean;
}

interface BackupResponse {
  success: boolean;
  data: {
    backupId: string;
    downloadUrl: string;
    size: string;
    createdAt: string;
    expiresAt: string;
  };
}
```

**API Call:**

```
POST /functions/v1/backup-database
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: BackupRequest
Response: BackupResponse
```

#### `get-app-settings` Edge Function

```typescript
interface AppSettings {
  general: {
    appName: string;
    timezone: string;
    dateFormat: string;
    currency: string;
  };
  sales: {
    defaultCommissionRate: number;
    maxSaleAmount: number;
    autoApprovalThreshold: number;
    requireApprovalFor: Sale["status"][];
  };
  notifications: {
    emailEnabled: boolean;
    pushEnabled: boolean;
    smsEnabled: boolean;
    adminNotifications: string[];
  };
  security: {
    sessionTimeout: number;
    passwordPolicy: {
      minLength: number;
      requireSpecialChars: boolean;
      requireNumbers: boolean;
      requireUppercase: boolean;
    };
    twoFactorEnabled: boolean;
  };
}

interface GetAppSettingsResponse {
  success: boolean;
  data: AppSettings;
}
```

**API Call:**

```
GET /functions/v1/get-app-settings
Authorization: Bearer <admin_token>

Response: GetAppSettingsResponse
```

#### `update-app-settings` Edge Function

```typescript
interface UpdateAppSettingsRequest {
  settings: Partial<AppSettings>;
}
```

**API Call:**

```
POST /functions/v1/update-app-settings
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: UpdateAppSettingsRequest
Response: StandardApiResponse
```

### 6. **Reporting Edge Functions**

#### `generate-admin-report` Edge Function

```typescript
interface AdminReportRequest {
  reportType: "sales" | "agents" | "commissions" | "performance" | "financial";
  dateFrom: string;
  dateTo: string;
  format: "pdf" | "excel" | "csv";
  filters?: {
    agentIds?: string[];
    saleStatuses?: Sale["status"][];
    amountRange?: {
      min: number;
      max: number;
    };
  };
}

interface AdminReportResponse {
  success: boolean;
  data: {
    reportId: string;
    downloadUrl: string;
    filename: string;
    generatedAt: string;
    expiresAt: string;
    summary: {
      totalRecords: number;
      dateRange: {
        from: string;
        to: string;
      };
    };
  };
}
```

**API Call:**

```
POST /functions/v1/generate-admin-report
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: AdminReportRequest
Response: AdminReportResponse
```

#### `get-financial-summary` Edge Function

```typescript
interface FinancialSummaryRequest {
  dateFrom: string;
  dateTo: string;
  groupBy: "day" | "week" | "month";
}

interface FinancialSummaryResponse {
  success: boolean;
  data: {
    totalRevenue: number;
    totalCommissions: number;
    netProfit: number;
    averageOrderValue: number;
    revenueGrowth: number;
    periodComparison: {
      current: {
        revenue: number;
        sales: number;
        commissions: number;
      };
      previous: {
        revenue: number;
        sales: number;
        commissions: number;
      };
      growth: {
        revenue: number;
        sales: number;
        commissions: number;
      };
    };
    breakdown: Array<{
      date: string;
      revenue: number;
      sales: number;
      commissions: number;
    }>;
  };
}
```

**API Call:**

```
POST /functions/v1/get-financial-summary
Authorization: Bearer <admin_token>
Content-Type: application/json

Body: FinancialSummaryRequest
Response: FinancialSummaryResponse
```

## Complete Admin Flow API Mapping

### 1. **Authentication Flow APIs**

- `POST /auth/v1/token` - Admin login
- `POST /auth/v1/refresh` - Token refresh
- `POST /auth/v1/logout` - Admin logout
- `GET /functions/v1/verify-admin-access` - Verify admin privileges

### 2. **Dashboard APIs**

- `GET /functions/v1/get-dashboard-stats` - Main dashboard statistics
- `POST /functions/v1/get-sales-analytics` - Detailed sales analytics
- `POST /functions/v1/get-financial-summary` - Financial summary data

### 3. **Agent Management APIs**

- `GET /functions/v1/get-agents` - List all agents
- `POST /functions/v1/create-agent` - Create new agent
- `POST /functions/v1/update-agent` - Update agent details
- `POST /functions/v1/deactivate-agent` - Deactivate agent
- `POST /functions/v1/get-agent-performance` - Agent performance metrics

### 4. **Sales Management APIs**

- `POST /functions/v1/get-sales` - List sales with filters
- `POST /functions/v1/update-sale` - Update single sale
- `POST /functions/v1/bulk-update-sales` - Bulk update sales
- `POST /functions/v1/export-sales-data` - Export sales data
- `GET /functions/v1/get-sale-details/{saleId}` - Get sale details

### 5. **Commission Management APIs**

- `POST /functions/v1/calculate-commissions` - Calculate commissions
- `POST /functions/v1/approve-commissions` - Approve commissions
- `GET /functions/v1/get-commission-history` - Commission history

### 6. **Notification APIs**

- `POST /functions/v1/send-bulk-notification` - Send bulk notifications
- `GET /functions/v1/get-notification-analytics` - Notification analytics
- `GET /functions/v1/get-notifications` - Get admin notifications

### 7. **System Administration APIs**

- `POST /functions/v1/get-system-logs` - System logs
- `POST /functions/v1/backup-database` - Database backup
- `GET /functions/v1/get-app-settings` - App settings
- `POST /functions/v1/update-app-settings` - Update settings

### 8. **Reporting APIs**

- `POST /functions/v1/generate-admin-report` - Generate reports
- `GET /functions/v1/get-report-history` - Report history
- `GET /functions/v1/download-report/{reportId}` - Download report

## Admin Flow State Management

### Global Admin State

```typescript
interface AdminState {
  // Authentication
  isAuthenticated: boolean;
  adminProfile: Profile | null;
  permissions: string[];

  // Dashboard
  dashboardStats: DashboardStats | null;
  isLoadingDashboard: boolean;

  // Agents
  agents: Agent[];
  selectedAgent: Agent | null;
  agentFilters: AgentFilters;
  isLoadingAgents: boolean;

  // Sales
  sales: Sale[];
  selectedSales: string[];
  salesFilters: SaleFilters;
  isLoadingSales: boolean;

  // System
  systemLogs: SystemLog[];
  appSettings: AppSettings | null;
  notifications: Notification[];

  // UI State
  activeTab: string;
  sidebarCollapsed: boolean;
  currentPage: string;
}
```

## Error Handling for Admin APIs

### Standard Error Response

```typescript
interface ApiError {
  success: false;
  error: {
    code: string;
    message: string;
    details?: any;
  };
  statusCode: number;
}
```

### Common Error Codes

- `UNAUTHORIZED` - Invalid or expired admin token
- `FORBIDDEN` - Insufficient admin privileges
- `VALIDATION_ERROR` - Invalid request data
- `NOT_FOUND` - Resource not found
- `RATE_LIMITED` - Too many requests
- `SERVER_ERROR` - Internal server error

## Complete Admin Navigation Flow

### 1. **Main Navigation Structure**

```
Admin Dashboard
├── Overview (Dashboard)
├── Sales Management
│   ├── All Sales
│   ├── Pending Sales
│   ├── Sales Analytics
│   └── Export Data
├── Agent Management
│   ├── All Agents
│   ├── Add Agent
│   ├── Agent Performance
│   └── Commission Management
├── Reports
│   ├── Sales Reports
│   ├── Financial Reports
│   ├── Agent Reports
│   └── Custom Reports
├── System
│   ├── Settings
│   ├── Notifications
│   ├── System Logs
│   └── Backup
└── Profile
    ├── Account Settings
    ├── Security
    └── Logout
```

### 2. **Page-specific API Calls**

#### Dashboard Page

```typescript
// On page load
const loadDashboard = async () => {
  const [stats, analytics, financial] = await Promise.all([
    api.call("get-dashboard-stats"),
    api.call("get-sales-analytics", {
      dateFrom: "2024-01-01",
      dateTo: "2024-12-31",
      groupBy: "month",
    }),
    api.call("get-financial-summary", {
      dateFrom: "2024-01-01",
      dateTo: "2024-12-31",
      groupBy: "month",
    }),
  ]);
};
```

#### Sales Management Page

```typescript
// On page load
const loadSales = async () => {
  const response = await api.call("get-sales", {
    limit: 50,
    offset: 0,
    filters: currentFilters,
  });
};

// On filter change
const applySalesFilters = async (filters: SaleFilters) => {
  const response = await api.call("get-sales", {
    limit: 50,
    offset: 0,
    filters,
  });
};

// On bulk update
const bulkUpdateSales = async (saleIds: string[], updates: any) => {
  const response = await api.call("bulk-update-sales", {
    saleIds,
    updates,
  });
};
```

#### Agent Management Page

```typescript
// On page load
const loadAgents = async () => {
  const response = await api.call("get-agents", {
    includeInactive: true,
  });
};

// On create agent
const createAgent = async (agentData: CreateAgentRequest) => {
  const response = await api.call("create-agent", agentData);
};

// On view performance
const viewAgentPerformance = async (agentId: string) => {
  const response = await api.call("get-agent-performance", {
    agentId,
    dateFrom: "2024-01-01",
    dateTo: "2024-12-31",
  });
};
```

---

This comprehensive continuation covers all remaining admin flow features, edge functions, API calls, and implementation details for complete backend integration. Every admin functionality now has complete API documentation with request/response interfaces, error handling, and flow mapping.
