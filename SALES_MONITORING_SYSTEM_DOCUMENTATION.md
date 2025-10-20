# Sales Monitoring System

## Complete System Documentation

**Generated on:** 16/09/2025  
**Version:** 1.0  
**Application Type:** Sales Monitoring & Management Platform

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Database Schema](#3-database-schema)
4. [User Roles & Permissions](#4-user-roles--permissions)
5. [Module Documentation](#5-module-documentation)
6. [Business Process Flows](#6-business-process-flows)
7. [Technical Specifications](#7-technical-specifications)
8. [API Documentation](#8-api-documentation)
9. [Troubleshooting Guide](#9-troubleshooting-guide)

---

## 1. Executive Summary

The **Sales Monitoring System** is a comprehensive dual-platform solution designed to streamline sales operations, agent management, and administrative oversight. This system provides integrated modules for sales transaction tracking, agent performance monitoring, and real-time analytics across mobile and web platforms.

### Key Features:

- **Multi-Platform Architecture**: Flutter mobile app for agents, Next.js web app for admins/super admins
- **Role-based Access Control** with granular permissions
- **Real-time Sales Tracking** and agent activity monitoring
- **Comprehensive Sales Management** with status workflow tracking
- **Multi-organization Support** with data isolation
- **Offline-first Capabilities** for mobile agents
- **Automated Reporting** and analytics dashboards
- **Image Upload & Management** for sales documentation

### Platform Distribution:

**Flutter Mobile Application:**

- **Agent Interface**: Sales form creation, history tracking, offline sync
- **Admin Interface**: Dashboard, sales management, agent oversight, monitoring

**Next.js Web Application:**

- **Admin Interface**: Sales management, agent management, analytics
- **Super Admin Interface**: Organization management, system administration

### Technology Stack:

**Frontend:**

- **Mobile**: Flutter with GetX state management
- **Web**: Next.js with React, TypeScript, Tailwind CSS

**Backend:**

- **Database**: Supabase (PostgreSQL) with real-time subscriptions
- **Authentication**: Supabase Auth with Row Level Security (RLS)
- **API**: Supabase Edge Functions (TypeScript/Deno)
- **File Storage**: Supabase Storage for images

**Additional Technologies:**

- **State Management**: GetX (Flutter), React Query (Next.js)
- **UI Libraries**: Custom components, Shadcn/UI
- **PDF Generation**: jsPDF for receipts and invoices
- **Maps Integration**: Google Maps for location tracking

---

## 2. System Architecture

### Architecture Overview:

The Sales Monitoring System follows a modern, scalable multi-platform architecture:

### 1. **Frontend Layer (Multi-Platform)**

**Flutter Mobile Application (Agent + Admin):**

- Component-based architecture using Flutter widgets
- GetX state management for reactive UI
- Offline-first data storage with sync capabilities
- Custom UI components following Material Design
- Local database for offline operations

**Next.js Web Application (Admin + Super Admin):**

- Component-based architecture using React
- TypeScript for type-safe development
- Responsive UI with Tailwind CSS
- State management with React Query
- Server-side rendering for performance

### 2. **Backend Services (Supabase)**

**Database Layer:**

- PostgreSQL database with real-time capabilities
- Row Level Security (RLS) for multi-tenant data isolation
- Automated backups and point-in-time recovery
- Database triggers for business logic automation

**Authentication & Authorization:**

- JWT-based authentication with automatic token refresh
- Role-based access control (RBAC)
- Session management across platforms
- Password policies and security enforcement

**API Layer:**

- TypeScript Edge Functions for custom business logic
- RESTful API design with standardized responses
- Real-time subscriptions for live data updates
- File upload handling for images and documents

### 3. **Security Layer**

**Data Protection:**

- End-to-end encryption for sensitive data
- Row-level security policies for data isolation
- API rate limiting and request validation
- Secure image upload and storage

**Authentication Security:**

- Multi-factor authentication support
- Session timeout and auto-refresh
- Role-based route protection
- Audit trails for sensitive operations

### 4. **Integration Layer**

**Third-party Services:**

- Google Maps API for location services
- Email services for notifications
- Image optimization and compression
- PDF generation for documents

### Key Architectural Principles:

- **Separation of Concerns**: Clear distinction between platforms and roles
- **Modular Design**: Feature-based organization for maintainability
- **Scalable Data Architecture**: Multi-tenant with organization isolation
- **Security-First Approach**: RLS and role-based access throughout
- **Performance Optimization**: Caching, pagination, and offline capabilities
- **Cross-Platform Consistency**: Shared business logic via API layer

---

## 3. Database Schema

### Database Tables Overview:

• **profiles**: User management and authentication across all platforms
• **organizations**: Partner organization management and multi-tenant support
• **sales**: Core sales transaction processing and lifecycle management
• **addresses**: Customer location data and geographic information management
• **uploads**: File attachment system for images and documents
• **sales_history**: Activity tracking and audit trail for all sales operations
• **stove_ids**: Individual stove unit tracking and inventory management
• **user_roles**: Enhanced role-based access control and permission management
• **sales_images**: Dedicated sales documentation image management
• **activity_logs**: System-wide activity monitoring and audit trails
• **notification_settings**: User notification preferences and delivery management

### Key Relationships:

- Users are organized by organizations and roles for comprehensive access control
- Organizations contain multiple sales agents and administrative users
- Sales transactions link customers to specific products and tracking information
- Stove IDs track individual products through the complete sales lifecycle
- Sales history maintains comprehensive audit trails for all transaction modifications
- Address data provides geographic tracking and location-based analytics
- Upload system manages all file attachments with proper access controls
- Branch management enables multi-location organizational support

### Security Implementation:

- Row Level Security (RLS) enabled on all tables for data isolation
- User access restricted based on organization membership and role assignments
- Organization-specific data isolation for complete multi-tenant security
- Comprehensive audit trails for all sensitive operations and data modifications
- Role-based permissions enforced at both database and application levels
- Automatic data encryption for sensitive fields including signatures and personal information

### Database Features:

- PostgreSQL with real-time capabilities via Supabase for live data updates
- Automatic timestamp tracking (created_at, updated_at) across all tables
- UUID primary keys for enhanced security and distributed system compatibility
- Foreign key constraints ensuring complete referential integrity
- Trigger-based automation for business logic and data validation
- Geographic data support for location-based features and mapping
- JSONB support for flexible metadata storage and complex data structures
- Full-text search capabilities for efficient sales and customer data retrieval

---

## 4. User Roles & Permissions

### Role Hierarchy:

#### 1. **Super Admin** (Web Platform Only)

**Access Level:** System-wide administration

**Permissions:**

- **Organization Management**: Create, update, delete organizations
- **Admin User Management**: Create and manage admin users across organizations
- **System Configuration**: Global system settings and configurations
- **Cross-Organization Reporting**: Access to aggregated data across all organizations
- **System Monitoring**: Access to system logs and performance metrics
- **Database Administration**: Direct database access and maintenance

**Platform Access:**

- ✅ Next.js Web Application (Full Access)
- ❌ Flutter Mobile Application (No Access)

**Key Features:**

- Manage multiple organizations
- Create admin accounts for partner organizations
- System-wide analytics and reporting
- Global configuration management

#### 2. **Admin** (Multi-Platform)

**Access Level:** Organization-wide administration

**Permissions:**

- **Sales Management**: View, edit, update all sales within organization
- **Agent Management**: Create, manage, and monitor sales agents
- **Sales Analytics**: Organization-specific dashboard and reporting
- **Sales Assignment**: Assign sales to agents for completion
- **Agent Performance Monitoring**: Track agent activities and performance
- **Organization Settings**: Manage organization-specific configurations

**Platform Access:**

- ✅ Next.js Web Application (Primary interface)
- ✅ Flutter Mobile Application (Administrative functions)

**Data Scope:**

- Limited to own organization data via RLS
- Cannot access other organizations' data
- Full CRUD access within organization scope

#### 3. **Agent** (Mobile Platform Only)

**Access Level:** Personal sales and assigned tasks

**Permissions:**

- **Sales Creation**: Create new sales transactions
- **Personal Sales History**: View own created/assigned sales
- **Sales Completion**: Complete assigned sales transactions
- **Profile Management**: Update personal profile information
- **Offline Operations**: Work offline with sync capabilities

**Platform Access:**

- ✅ Flutter Mobile Application (Primary interface)
- ❌ Next.js Web Application (No Access)

**Data Scope:**

- Own created sales transactions
- Sales assigned by admin
- Personal activity history
- Organization stove inventory (read-only)

### Permission Matrix:

| Feature                     | Super Admin | Admin        | Agent           |
| --------------------------- | ----------- | ------------ | --------------- |
| **Organization Management** | ✅ Full     | ❌ None      | ❌ None         |
| **Create Admin Users**      | ✅ Yes      | ❌ No        | ❌ No           |
| **Sales Management**        | ✅ All Orgs | ✅ Own Org   | ✅ Own/Assigned |
| **Agent Management**        | ✅ All Orgs | ✅ Own Org   | ❌ None         |
| **Dashboard Analytics**     | ✅ Global   | ✅ Org-level | ✅ Personal     |
| **Sales Assignment**        | ✅ Yes      | ✅ Yes       | ❌ No           |
| **System Configuration**    | ✅ Yes      | ❌ No        | ❌ No           |
| **Cross-Org Reporting**     | ✅ Yes      | ❌ No        | ❌ No           |
| **Mobile App Access**       | ❌ No       | ✅ Yes       | ✅ Yes          |
| **Web App Access**          | ✅ Yes      | ✅ Yes       | ❌ No           |

### Security Implementation:

**Row Level Security (RLS) Policies:**

• **Organization Access Control**: Super admin users can view all organizations while regular users are restricted to their assigned organization only
• **Sales Data Isolation**: Users can only access sales data that belongs to their organization, ensuring complete data separation between different partner organizations
• **Profile Visibility**: Users can view profile information for members within their organization plus their own profile details
• **Automated Policy Enforcement**: Database-level security policies automatically filter data based on user authentication and role assignments

**Platform-Specific Access Control:**

**Flutter Mobile Application Security:**
• Session-based role verification performed during application startup
• Route navigation guards that restrict access based on user role and permissions
• Offline role persistence ensuring security is maintained even without internet connectivity
• Automatic session termination and logout when role changes are detected
• Encrypted local storage for sensitive authentication data

**Next.js Web Application Security:**
• JWT-based authentication with embedded role claims for seamless authorization
• Protected route middleware that validates user permissions before page access
• Component-level permission checking for granular UI element control
• Automatic redirection to appropriate pages when unauthorized access is attempted
• Session timeout management with automatic renewal capabilities

---

## 5. Module Documentation

### 5.1 Sales Management Module

**Comprehensive sales transaction processing and lifecycle management**

#### Core Features:

**Sales Creation & Processing:**

- Multi-step sales form with validation
- Image capture for stove and agreement photos
- Digital signature collection
- Location data capture with GPS coordinates
- Offline creation with automatic sync

**Sales Status Management:**

- **Incomplete**: Initial creation state
- **Pending**: Submitted for review
- **Assigned**: Assigned to agent for completion
- **Completed**: Final processed state

**Sales Analytics & Reporting:**

- Advanced filtering by date, location, amount, status
- Export capabilities (CSV, PDF reports)
- Real-time analytics dashboard
- Performance metrics and trends

#### Platform Implementation:

**Flutter Mobile Application (Agent + Admin):**

**Sales Form Controller Architecture:**
• Service integration layer connecting form controllers to backend Supabase services
• Observable loading states for real-time UI feedback during form submission
• Reactive sales data model that updates UI automatically when data changes
• Comprehensive error handling with user-friendly toast notifications
• Offline-first form submission with automatic sync when connectivity returns
• Form validation with real-time field checking and error display
• Image compression and local storage before cloud upload
• Digital signature capture with canvas-based drawing interface

**Next.js Web Application (Admin + Super Admin):**

**Sales Management Service Architecture:**
• Advanced filtering system supporting multiple criteria including date ranges, locations, amounts, and status types
• Real-time data fetching with automatic refresh capabilities
• Sales status management with workflow-based transitions
• Bulk operations support for managing multiple sales records simultaneously
• Export functionality for generating CSV and PDF reports
• Performance optimization through pagination and virtual scrolling
• Comprehensive error handling with user feedback mechanisms
• Real-time notifications for sales updates and status changes

### 5.2 Agent Management Module

**Sales agent lifecycle management and performance tracking**

#### Core Features:

**Agent Account Management:**

- Agent registration with auto-generated credentials
- Role assignment and permission management
- Profile management and updates
- Password reset and security management

**Performance Monitoring:**

- Real-time activity tracking
- Sales performance metrics
- Daily, weekly, monthly statistics
- Productivity analytics and reporting

**Agent Assignment System:**

- Sales assignment to specific agents
- Task management and tracking
- Completion status monitoring
- Performance-based assignment optimization

#### Implementation:

**Flutter Admin Interface:**

**Agent Management Controller Features:**
• Comprehensive agent service integration for complete lifecycle management
• Observable sales agent collection with real-time updates and automatic UI refresh
• Agent creation workflow with validation, role assignment, and organization linkage
• Performance monitoring dashboard with real-time activity tracking
• Bulk operations support for managing multiple agents efficiently
• Search and filtering capabilities for large agent databases
• Agent status management including activation, deactivation, and role modifications
• Integration with notification system for agent-related alerts and updates

**Next.js Admin Interface:**

**Agent Service Architecture:**
• Advanced agent creation with auto-generated secure credentials and email delivery
• Comprehensive performance analytics including sales metrics, activity patterns, and productivity scores
• Territory management for geographic assignment and tracking
• Commission calculation and tracking system integration
• Advanced reporting with customizable date ranges and performance indicators
• Agent hierarchy management for team-based organizational structures
• Real-time activity monitoring with location tracking and task completion status
• Integration with communication systems for direct messaging and notification delivery

### 5.3 Dashboard & Analytics Module

**Real-time business intelligence and performance monitoring**

#### Core Features:

**Executive Dashboard:**

- Organization-wide KPI overview
- Sales performance metrics
- Agent productivity statistics
- Financial summaries and trends

**Real-time Monitoring:**

- Live sales creation tracking
- Agent activity monitoring
- System performance metrics
- Alert and notification system

**Advanced Analytics:**

- Time-series analysis of sales data
- Geographic distribution mapping
- Agent performance comparisons
- Revenue and growth projections

#### Implementation:

**Dashboard Data Service Architecture:**

**Core Statistics Management:**
• Total sales count tracking with real-time updates from database triggers
• Sales agent performance metrics including individual and team statistics
• Completed sales monitoring with status-based filtering and counting
• Geographic landmark integration showing sales with precise location data
• Pending sales queue management with priority-based sorting
• Financial analytics including total sales amounts, revenue tracking, and commission calculations
• Inventory management integration tracking total stoves received, sold, and available
• Real-time data synchronization ensuring dashboard reflects current system state

**Advanced Analytics Features:**
• Time-series data analysis for trend identification and forecasting
• Geographic heat mapping for sales distribution visualization
• Agent performance comparison with ranking and benchmarking
• Revenue projection modeling based on historical data and current trends
• Custom date range analysis for flexible reporting periods
• Export capabilities for offline analysis and presentation preparation
• Real-time alert system for threshold-based notifications
• Integration with third-party analytics tools for advanced data processing

### 5.4 Organization Management Module

**Multi-tenant organization administration (Super Admin Only)**

#### Core Features:

**Organization CRUD Operations:**

- Create new partner organizations
- Manage organization profiles and settings
- Organization deactivation and reactivation
- Bulk organization operations

**Admin User Management:**

- Create admin accounts for organizations
- Manage admin permissions and roles
- Cross-organization user administration
- Security and compliance oversight

#### Implementation:

**Organization Route Handler Architecture:**

**HTTP Method Support:**
• GET operations for retrieving organization lists with pagination and filtering
• POST operations for creating new partner organizations with validation and setup
• PUT operations for updating organization details, settings, and configurations
• DELETE operations for organization deactivation with data preservation protocols

**Advanced Organization Management:**
• Multi-step organization onboarding with guided setup processes
• Integration with billing and subscription management systems
• Data migration tools for importing existing organizational data
• Compliance monitoring for regulatory requirements and audit trails
• Custom branding and configuration options for white-label solutions
• API integration capabilities for connecting with partner systems
• Advanced user provisioning with role-based access templates
• Automated backup and disaster recovery procedures for organizational data

### 5.5 Offline Synchronization Module

**Offline-first architecture for mobile operations**

#### Core Features:

**Local Data Storage:**

- SQLite local database for offline operations
- Automatic data caching and management
- Conflict resolution strategies
- Data integrity verification

**Sync Management:**

- Background synchronization processes
- Incremental sync for performance
- Retry mechanisms for failed syncs
- Progress tracking and user feedback

**Conflict Resolution:**

- Last-write-wins conflict resolution
- Manual conflict resolution interface
- Data versioning and audit trails
- Rollback capabilities for errors

---

## 6. Business Process Flows

### 6.1 Sales Transaction Workflow

#### Process Overview:

Complete sales transaction lifecycle from creation to completion

#### Key Stakeholders:

- **Sales Agent**: Creates and submits sales
- **Admin**: Reviews, assigns, and monitors sales
- **System**: Automated processing and notifications

#### Workflow Steps:

**Step 1: Sales Creation (Agent)**

```
Agent → Mobile App → Sales Form
  ↓
Data Collection:
  - Customer information (name, phone, address)
  - Product details (stove serial number)
  - Financial information (amount, payment method)
  - Documentation (photos, signature)
  - Location data (GPS coordinates)
  ↓
Validation & Storage:
  - Form validation (required fields, format checks)
  - Image compression and upload
  - Local storage (offline capability)
  - Status: "Incomplete"
```

**Step 2: Sales Submission (Agent)**

```
Agent → Review → Submit
  ↓
Submission Process:
  - Final validation and review
  - Image upload to cloud storage
  - Data synchronization to server
  - Status Change: "Incomplete" → "Pending"
  ↓
Automatic Actions:
  - Admin notification
  - Activity log creation
  - Dashboard metrics update
```

**Step 3: Sales Review & Assignment (Admin)**

```
Admin → Dashboard → Sales Management
  ↓
Review Process:
  - Sales data validation
  - Customer information verification
  - Documentation review
  - Geographic data confirmation
  ↓
Assignment Decision:
  - Assign to agent for completion
  - Status Change: "Pending" → "Assigned"
  - Agent notification
```

**Step 4: Sales Completion (Agent)**

```
Agent → Assigned Sales → Complete
  ↓
Completion Process:
  - Final customer confirmation
  - Additional documentation if needed
  - Completion form submission
  - Status Change: "Assigned" → "Completed"
  ↓
Final Actions:
  - Inventory update (stove status)
  - Financial record creation
  - Performance metrics update
  - Completion notification to admin
```

### 6.2 Agent Management Workflow

#### Process Overview:

Sales agent lifecycle from recruitment to performance management

#### Workflow Steps:

**Step 1: Agent Recruitment (Admin)**

```
Admin → Agent Management → Add New Agent
  ↓
Agent Creation:
  - Basic information collection (name, email, phone)
  - Auto-generated secure password
  - Organization assignment
  - Role configuration (agent)
  ↓
Account Setup:
  - Supabase Auth account creation
  - Profile record creation
  - Organization linkage
  - Initial password assignment
```

**Step 2: Agent Onboarding**

```
System → Email/SMS Notification → Agent
  ↓
Agent Activation:
  - Credential sharing (secure method)
  - Mobile app download instructions
  - Initial login and password change
  - Profile completion
  ↓
Training & Setup:
  - App tutorial and training
  - Territory assignment (if applicable)
  - Target setting and goal alignment
  - System familiarization
```

**Step 3: Ongoing Performance Management**

```
Daily Operations:
  - Sales creation and submission
  - Activity tracking and monitoring
  - Performance metric collection
  - Real-time dashboard updates
  ↓
Performance Review:
  - Weekly/monthly performance analysis
  - KPI evaluation and feedback
  - Goal adjustment and target setting
  - Recognition and improvement planning
```

### 6.3 Organization Management Workflow (Super Admin)

#### Process Overview:

Partner organization lifecycle and administration

#### Workflow Steps:

**Step 1: Organization Onboarding**

```
Super Admin → Organization Management → Create Organization
  ↓
Organization Setup:
  - Partner organization details
  - Contact information and billing
  - Initial configuration and settings
  - Data isolation setup
```

**Step 2: Admin User Creation**

```
Super Admin → Create Admin User
  ↓
Admin Account Setup:
  - Admin user credentials
  - Organization assignment
  - Permission configuration
  - Access provisioning
```

**Step 3: Ongoing Administration**

```
Continuous Operations:
  - Organization monitoring and support
  - Performance analytics and reporting
  - System maintenance and updates
  - Billing and subscription management
```

---

## 7. Technical Specifications

### 7.1 Flutter Mobile Application

#### Development Environment:

- **Flutter SDK**: Version 3.19.0 and above for optimal performance and feature support
- **Dart Version**: 3.3.0 and above ensuring latest language features and null safety
- **Target Platforms**: Android 5.0+ (API level 21) and iOS 12.0+ for broad device compatibility
- **Architecture**: Model-View-ViewModel (MVVM) pattern with GetX state management for reactive programming

#### Key Dependencies and Libraries:

**Core Framework Dependencies:**
• Flutter SDK providing cross-platform mobile development capabilities
• GetX library for state management, dependency injection, and route management
• Supabase Flutter for seamless backend integration and real-time data synchronization
• Get Storage for local data persistence and offline functionality
• Logger package for comprehensive debugging and error tracking

**Feature-Specific Dependencies:**
• Google Maps Flutter for location services and mapping functionality
• Image Picker for camera integration and photo capture capabilities
• Permission Handler for managing device permissions and user privacy
• Toastification for user-friendly notification and feedback systems
• Shimmer effects for enhanced loading states and user experience

#### Architecture Components:

**State Management Pattern Implementation:**
• Controller classes extending GetX controller for reactive state management
• Service layer integration connecting controllers to backend Supabase services
• Observable variables for real-time UI updates and automatic state synchronization
• Lifecycle management with proper initialization and cleanup procedures
• Error handling mechanisms with user-friendly feedback and recovery options
• Loading state management for improved user experience during data operations

**Service Layer Pattern Architecture:**
• Dedicated service classes for each major functionality area
• Supabase service integration for backend communication and data operations
• Response handling with proper success and error state management
• Data transformation between API responses and local model objects
• Retry mechanisms for failed operations and network connectivity issues
• Caching strategies for improved performance and offline functionality

#### Offline Capabilities:

**Local Data Storage Solutions:**
• Get Storage implementation for key-value pair storage and user preferences
• Local file system integration for image storage with automatic compression
• Background synchronization processes for seamless online/offline transitions
• Data persistence ensuring no loss of user work during connectivity issues
• Automatic cache management with intelligent cleanup and optimization strategies

### 7.2 Next.js Web Application

#### Development Environment:

- **Next.js Version**: 15.1.6 providing modern React framework capabilities and server-side rendering
- **React Version**: 19.0.0 offering latest component architecture and concurrent features
- **TypeScript**: 5.6.0+ ensuring complete type safety and enhanced development experience
- **Node.js Runtime**: 18.0.0+ for optimal performance and latest JavaScript features

#### Key Dependencies and Libraries:

**Core Framework Dependencies:**
• Next.js framework for server-side rendering, static site generation, and API routes
• React and TypeScript providing component-based architecture with type safety
• Supabase JavaScript client for seamless backend integration and real-time capabilities
• Radix UI components for accessible and customizable user interface elements
• Tailwind CSS for utility-first styling and responsive design system

**Feature-Specific Dependencies:**
• jsPDF library for comprehensive PDF generation and document export functionality
• Date-fns for advanced date manipulation, formatting, and timezone handling
• Framer Motion for smooth animations and interactive user experience enhancements
• Custom UI component library built on Radix UI primitives for consistent design
• Utility libraries for data validation, form handling, and state management

#### Architecture Components:

**API Service Pattern Implementation:**
• Centralized API service class providing consistent interface for all backend operations
• Supabase client configuration with automatic authentication and session management
• Edge function integration for serverless backend operations and business logic execution
• Error handling mechanisms with proper exception catching and user-friendly feedback
• Response standardization ensuring consistent data format across all API endpoints
• Retry logic with exponential backoff for failed requests and network resilience

**Component Architecture Strategy:**
• Page-level components serving as route handlers and main application entry points
• Custom hooks implementing data fetching, state management, and business logic
• Loading and error state components providing consistent user feedback patterns
• Reusable UI components with proper prop interfaces and TypeScript definitions
• Layout components ensuring consistent application structure and navigation
• Query management with automatic caching, background updates, and optimistic UI

#### Advanced Development Features:

**Performance Optimization Techniques:**
• Server-side rendering for improved initial page load times and SEO optimization
• Static site generation for content pages with predictable data requirements
• Automatic code splitting reducing bundle sizes and improving application performance
• Image optimization with Next.js built-in image component for faster loading
• API route optimization with proper caching headers and response compression
• Database query optimization with efficient joins and indexed lookups

### 7.3 Supabase Backend Configuration

#### Database Configuration:

- **Database Engine**: PostgreSQL 15+ providing robust relational database capabilities and advanced features
- **Connection Management**: PgBouncer connection pooling for optimal performance and resource utilization
- **Backup Strategy**: Daily automated backups with point-in-time recovery capabilities
- **Scaling Architecture**: Horizontal read replicas for improved performance and load distribution
- **Security Features**: Row Level Security (RLS) policies ensuring data isolation and access control

#### Edge Functions Implementation:

**Function Architecture:**
• TypeScript-based serverless functions providing business logic execution
• Authentication middleware ensuring secure access to protected operations
• Input validation and sanitization for data integrity and security compliance
• Error handling with appropriate HTTP status codes and user-friendly messages
• CORS configuration enabling proper cross-origin request handling
• Response standardization with consistent JSON structure across all endpoints

**Key Functions by Category:**

**Authentication and User Management:**
• User registration and login verification with secure password handling
• Profile management including data updates and preference settings
• Session management with automatic token refresh and validation
• Password reset functionality with secure token generation and validation
• Role-based access control ensuring proper permission management

**Sales Management Operations:**
• Sales record creation with comprehensive data validation and business rule enforcement
• Sales data retrieval with filtering, sorting, and pagination capabilities
• Sales status updates with proper workflow management and notification systems
• Sales reporting with aggregated data calculations and performance metrics
• Bulk operations for efficient data management and administrative tasks

**Organizational Management:**
• Multi-tenant architecture supporting organization-specific data isolation
• Branch management with hierarchical structure and permission inheritance
• User assignment and role management within organizational boundaries
• Organization-level settings and configuration management
• Cross-organization reporting for super admin access and system monitoring

#### Real-time Capabilities:

**Live Data Synchronization:**
• PostgreSQL change data capture for real-time database event streaming
• WebSocket connections for instant client updates without polling overhead
• Subscription management for selective data updates based on user permissions
• Conflict resolution mechanisms for concurrent data modifications
• Automatic reconnection handling for improved reliability and user experience

#### Security Implementation:

**Row Level Security (RLS) Policies:**
• Organization-based data isolation ensuring users only access their data
• Role-based access control with fine-grained permission management
• Dynamic policy evaluation based on user context and session information
• Audit trail implementation tracking all data access and modification events
• Compliance features meeting data protection and privacy regulations

#### Edge Functions Architecture:

**Standard Edge Function Pattern:**
• Deno runtime environment providing secure and efficient serverless execution
• HTTP server implementation with proper request/response handling patterns
• CORS middleware ensuring proper cross-origin request support for web applications
• Authentication verification using Supabase JWT token validation
• Request routing with appropriate HTTP method handling (GET, POST, PUT, DELETE)
• Error handling with structured JSON responses and appropriate HTTP status codes
• Business logic separation maintaining clean architecture and testability

**Security Implementation:**
• JWT token verification for authenticated requests ensuring user identity validation
• Automatic user session management with proper authentication state handling
• Role-based access control preventing unauthorized access to protected resources
• Input validation and sanitization protecting against malicious data injection
• Error response standardization preventing information leakage to potential attackers

#### Security Configuration:

- **Row Level Security**: Enabled on all database tables ensuring data isolation between organizations
- **JWT Verification**: Automatic token validation with proper error handling for expired sessions
- **API Rate Limiting**: Request throttling per user preventing abuse and ensuring fair resource usage
- **CORS Configuration**: Restricted origin access ensuring only authorized domains can access the API

### 7.4 Performance Specifications

#### Mobile Application Performance:

- **App Startup Time**: < 3 seconds cold start
- **Sales Form Submission**: < 5 seconds with images
- **Offline Sync**: Background processing, non-blocking UI
- **Memory Usage**: < 150MB average during normal operation

#### Web Application Performance:

- **Page Load Time**: < 2 seconds initial load
- **API Response Time**: < 500ms for most operations
- **Large Dataset Handling**: Pagination with virtual scrolling
- **Bundle Size**: < 2MB initial JavaScript bundle

#### Backend Performance:

- **Database Query Performance**: < 100ms for indexed queries
- **Edge Function Execution**: < 1 second average
- **File Upload**: Support up to 10MB images with compression
- **Concurrent Users**: Designed for 1000+ concurrent users

---

## 8. API Documentation

### 8.1 Authentication Endpoints

#### Supabase Auth Integration

**User Authentication Process:**
• Email and password-based login with secure credential validation
• Automatic session management with JWT token generation and refresh capabilities
• User profile retrieval with comprehensive user information and role assignments
• Secure logout functionality with proper session cleanup and token invalidation
• Password reset workflows with secure token generation and email verification

**Authentication Features:**
• Multi-factor authentication support for enhanced security
• Social login integration options for improved user experience
• Session persistence across application restarts and device changes
• Automatic token refresh preventing session expiration during active use
• Role-based authentication ensuring proper access control and permission management

### 8.2 Core Edge Functions

#### Dashboard Statistics

**get-dashboard-stats Endpoint:**
• GET method requiring admin role authentication for secure access to system metrics
• Returns comprehensive dashboard statistics including sales totals and performance indicators
• Data includes total sales count, active sales agents, completed transactions metrics
• Provides stove inventory information including received, sold, and available counts
• Includes financial metrics such as total sales amount and revenue calculations
• Real-time data aggregation ensuring up-to-date statistics for decision making

**Response Data Structure:**
• Success indicator with boolean flag for operation status confirmation
• Total sales count providing overview of all sales transactions in the system
• Sales agents count showing active agent workforce and capacity metrics
• Completed sales metrics indicating successful transaction completion rates
• Stoves with landmark data showing geographical distribution and tracking
• Pending sales information for workload management and priority setting
• Financial totals including sales amounts and revenue calculations
• Inventory status with detailed stove availability and distribution metrics

#### Sales Management

**get-sales-advanced Endpoint:**
• POST method with comprehensive filtering and search capabilities
• Authentication required for secure access to sales data and customer information
• Advanced search functionality supporting multiple criteria and flexible querying
• Date range filtering for temporal analysis and reporting requirements
• Location-based filtering by states and local government areas for regional insights
• Status filtering supporting pending, completed, assigned, and incomplete states
• Pagination support for efficient data loading and improved user experience
• Sorting capabilities with customizable field selection and order preferences

**Request Parameters:**
• Search term support for cross-field text matching and flexible data discovery
• Stove serial number filtering for specific device tracking and identification
• End user name search for customer-specific data retrieval and management
• Partner name filtering for business relationship management and analytics
• Phone number search enabling contact-based customer identification
• Date range parameters supporting from/to filtering for temporal analysis
• Geographic filtering with state and LGA selection for regional reporting
• Status array filtering enabling multiple status selection and complex queries
• Pagination controls with page number and limit settings for performance optimization
• Sorting configuration with field selection and ascending/descending order options

**Response Structure:**
• Success flag indicating operation completion status and error handling
• Sales data array containing complete transaction records with all relevant details
• Pagination metadata including current page, limit settings, and total record counts
• Total pages calculation for navigation and user interface pagination controls

#### Agent Management

**create-agent-user Endpoint:**
• POST method requiring admin role authentication for secure agent creation
• User account creation with automatic profile setup and credential generation
• Secure password generation with automatic email delivery to new agents
• Role assignment with proper permission configuration for agent-level access
• Integration with organization structure ensuring proper data isolation

**Request Parameters:**
• Full name field for agent identification and contact management
• Email address serving as unique identifier and communication channel
• Optional phone number for additional contact information and verification
• Automatic role assignment to agent level with appropriate permissions
• Organization context inheritance from authenticated admin user

**Response Structure:**
• Success indicator confirming successful agent creation and setup
• User object containing authentication details and account information
• Profile data with complete agent information and organizational assignment
• Generated password for initial login and account activation
• Account status information including password change requirements

**get-sales-agents Endpoint:**
• GET method for retrieving complete list of sales agents within organization
• Admin role authentication ensuring proper access control and data security
• Comprehensive agent information including contact details and status
• Role verification and permission tracking for administrative oversight
• Account status monitoring including password change tracking

**Agent Data Structure:**
• Unique identifier for agent tracking and system integration
• Full name for identification and user interface display purposes
• Email address for communication and authentication purposes
• Optional phone number for additional contact and verification methods
• Role information confirming agent status and permission levels
• Account creation timestamp for administrative tracking and reporting
• Password change status for security compliance and user experience management

#### Organization Management (Super Admin Only)

**manage-organizations Endpoint:**
• Multiple HTTP methods (GET, POST, PUT, DELETE) for comprehensive organization management
• Super admin role authentication ensuring highest level access control
• Organization creation, retrieval, updating, and deletion capabilities
• Partner email management for organization communication and billing
• System-wide administrative oversight and control

**Organization Data Structure:**
• Unique identifier for organization tracking and system-wide data isolation
• Organization name for display and administrative identification purposes
• Partner email for primary contact and business communication
• Creation timestamp for administrative tracking and system auditing
• Additional metadata for organizational management and reporting

**Create Organization Request:**
• Organization name requirement for identification and system setup
• Partner email designation for primary contact and communication
• Automatic system configuration for new organization setup
• Default permission structure creation for organizational hierarchy
• Integration with existing user management and role assignment systems

### 8.3 Error Handling

#### Standard Error Response Format

**Error Response Structure:**
• Success flag set to false indicating operation failure and error condition
• User-friendly message providing clear explanation of error cause and resolution
• Optional error details for debugging and technical support purposes
• HTTP status code indicating specific error type and appropriate handling
• Timestamp for error tracking and system monitoring purposes

**Common HTTP Status Codes:**
• 200: Successful operation completion with data returned
• 400: Bad Request indicating validation errors or malformed input
• 401: Unauthorized access requiring authentication credentials
• 403: Forbidden operation due to insufficient permissions
• 404: Resource not found indicating invalid endpoint or data
• 500: Internal Server Error indicating system-level issues requiring investigation

#### Error Handling Best Practices

**Client-side Error Management:**
• Try-catch blocks for proper exception handling and user experience
• Response validation checking success flags before processing data
• User-friendly error messages displayed through toast notifications
• Fallback mechanisms for graceful degradation during errors
• Logging mechanisms for debugging and system monitoring
• Retry strategies for transient errors and network connectivity issues
• Error state management in user interface components
• Proper cleanup and resource management during error conditions

### 8.4 Request/Response Patterns

#### Standard Request Headers

**Authentication Header:**
• Bearer token authentication using JWT format for secure API access
• Content-Type specification ensuring proper data format handling
• Client platform identification for request tracking and optimization
• Request correlation IDs for debugging and monitoring purposes
• API version headers for backward compatibility and feature management

#### Pagination Pattern

**Pagination Request Structure:**
• Page number using 1-based indexing for intuitive user interface navigation
• Items per page limit with maximum of 1000 for performance optimization
• Optional offset parameter providing alternative pagination mechanism
• Sort order specification for consistent data ordering across requests
• Filter preservation ensuring pagination maintains applied search criteria

**Pagination Response Structure:**
• Current page number for navigation state management
• Items per page confirmation matching request parameters
• Total record count for pagination calculation and user interface display
• Total pages calculation for navigation component rendering
• Has more indicator for infinite scroll and progressive loading implementations
• Offset value for alternative pagination approaches and optimization

#### Filter Pattern

**Standard Filter Request:**
• Global text search supporting cross-field matching and flexible queries
• Date range filtering with ISO date string format for temporal analysis
• Sort field specification with ascending/descending order options
• Domain-specific filters for targeted data retrieval and analysis
• Multiple filter combination support for complex query requirements
• Filter state preservation across pagination and navigation operations

---

## 9. Troubleshooting Guide

### 9.1 Common Authentication Issues

#### Issue: User Cannot Login

**Symptoms:**

- Login form shows "Invalid credentials" error
- Authentication fails consistently with correct credentials

**Diagnosis Steps:**

1. Verify email format follows standard email validation patterns
2. Check if user account exists in profiles table with correct organization assignment
3. Verify password change requirements and account status
4. Check user role assignments and organizational permissions

**Solutions:**

**User Profile Verification:**
• Database query to check user profile existence and status
• Email address verification in profiles table
• Role and organization assignment confirmation
• Password change flag status review for first-time login requirements

**Password Reset Process:**
• Update password change flag for users requiring password reset
• Clear authentication cache and stored credentials
• Generate new temporary passwords through admin interface
• Email notification system for password reset instructions

#### Issue: Token Refresh Failures

**Symptoms:**

- Frequent automatic logouts during active sessions
- "Session expired" errors for authenticated users
- API calls returning 401 Unauthorized despite valid login

**Solutions:**

**Client-side Token Management:**
• Automatic token refresh implementation monitoring session expiration
• Session validation checking before API calls
• Token expiration detection with proactive refresh mechanisms
• Fallback authentication flow for failed refresh attempts

**Browser Storage Management:**
• Clear all authentication data from local and session storage
• Remove cached credentials and session tokens
• Reset authentication state in application memory
• Redirect to login page with appropriate error messaging

### 9.2 Database Performance Issues

#### Issue: Slow Query Performance

**Symptoms:**

- Dashboard statistics loading slowly or timing out
- Sales filtering operations taking more than 5 seconds
- High database CPU usage affecting overall system performance

**Diagnosis Process:**

**Query Performance Analysis:**
• Slow query identification using PostgreSQL statistics views
• Execution time analysis for frequently used queries
• Table statistics review for insert, update, and delete operations
• Database connection monitoring and resource utilization tracking

**Performance Monitoring:**
• Query execution plan analysis for optimization opportunities
• Index usage patterns and effectiveness measurement
• Database lock monitoring for concurrent operation conflicts
• Memory usage patterns and buffer cache efficiency

**Solutions:**

**Database Index Optimization:**
• Create composite indexes for multi-field filtering operations
• Implement GIN indexes for full-text search capabilities
• Add covering indexes for frequently accessed query patterns
• Remove unused indexes to improve write performance

**Query Optimization Strategies:**
• Use EXPLAIN ANALYZE for query execution plan analysis
• Optimize JOIN operations and subquery patterns
• Implement pagination for large result sets
• Cache frequently accessed aggregated data

### 9.3 Mobile App Issues

#### Issue: Offline Sync Failures

**Symptoms:**

- Sales data not synchronizing with server after connectivity restoration
- "Sync failed" error messages appearing repeatedly
- Data loss occurring after application restart or update

**Diagnosis Steps:**

1. Check internet connectivity status and quality
2. Verify authentication status and token validity
3. Check local storage integrity and available space
4. Review sync queue status and pending operations

**Solutions:**

**Manual Sync Implementation:**
• Force sync functionality for manual synchronization triggers
• Comprehensive error handling with user-friendly feedback messages
• Sequential sync process for pending sales, images, and cache updates
• Success confirmation with toast notifications for user awareness

**Data Integrity Measures:**
• Validation of local data before sync attempts
• Conflict resolution for concurrent data modifications
• Backup mechanisms for critical data preservation
• Recovery procedures for failed sync operations

#### Issue: Image Upload Failures

**Symptoms:**

- Sales submission failures specifically related to image processing
- Large file upload operations timing out before completion
- Memory errors occurring during image compression and processing

**Solutions:**

**Image Compression Strategy:**
• Automatic image quality reduction to optimize file sizes for faster uploads
• Resolution constraints maintaining visual quality while reducing data transmission
• Progressive compression based on device capabilities and network conditions
• Base64 encoding for standardized data transmission format compatibility

**Upload Retry Mechanisms:**
• Exponential backoff strategy for failed upload attempts with intelligent timing
• Maximum retry limits preventing infinite retry loops and resource exhaustion
• Error-specific retry logic handling different failure types appropriately
• Progress tracking and user feedback during upload operations for better experience

### 9.4 API Issues

#### Issue: Edge Function Timeouts

**Symptoms:**

- API requests consistently timeout after 30 seconds of execution
- Inconsistent response times affecting user experience
- Function execution errors due to processing complexity

**Solutions:**

**Function Performance Optimization:**
• Early return validation preventing unnecessary processing for invalid requests
• Input validation at function entry point reducing computation overhead
• Connection pooling configuration for efficient database resource management
• Response caching for frequently requested data to reduce processing time

**Request Timeout Management:**
• Client-side timeout implementation with race condition handling
• Timeout promises providing fallback mechanisms for long-running operations
• Graceful timeout handling with appropriate error messaging for users
• Progressive timeout strategies based on operation complexity and expected duration

#### Issue: Rate Limiting

**Symptoms:**

- "Too many requests" errors appearing during high usage periods
- API calls being blocked or rejected by rate limiting mechanisms
- Degraded performance under concurrent load from multiple users

**Solutions:**

**Request Queuing Implementation:**
• Concurrent request limitation preventing server overload
• Queue management with intelligent request prioritization
• Promise-based queue handling with automatic cleanup and resource management
• Load balancing strategies distributing requests across available resources

### 9.5 Data Consistency Issues

#### Issue: RLS Policy Conflicts

**Symptoms:**

- Users accessing data from other organizations outside their permission scope
- Permission denied errors for operations that should be allowed
- Inconsistent data access patterns affecting user experience and security

**Solutions:**

**RLS Policy Review Process:**
• Comprehensive policy audit checking all tables and permission configurations
• Policy effectiveness testing using role simulation and permission verification
• Policy logic validation ensuring proper organization-based data isolation
• Permission inheritance review for complex organizational structures

**Policy Testing and Validation:**
• Role-based testing simulating different user types and permission levels
• Data access verification ensuring users only see appropriate organizational data
• Permission boundary testing confirming proper access control enforcement
• Policy conflict resolution for overlapping or contradictory permission rules

**Policy Logic Correction:**
• Organization isolation policy review and correction procedures
• DROP and CREATE policy statements for policy replacement and updates
• User access verification testing after policy modifications
• Comprehensive testing ensuring proper data access patterns post-correction

### 9.6 Emergency Procedures

#### System Recovery Steps

**Database Recovery Process:**
• Emergency admin access creation for critical system recovery situations
• Profile insertion with super admin privileges for system management
• Organization bypass capabilities for emergency administrative access
• UUID generation for emergency accounts with appropriate role assignments

**Service Restart Procedure:**
• Edge function redeployment with project reference specification
• Cache clearing procedures for data consistency restoration
• Service health verification after restart operations
• Monitoring system restart to ensure proper service restoration

# Restart application

pm2 restart all

````

3. **Data Backup and Restore:**
```bash
# Create backup
pg_dump -h <host> -U <user> -d <database> > backup.sql

**Data Backup and Restoration:**
• Database backup creation using PostgreSQL dump utilities
• Backup file restoration procedures for disaster recovery
• Data integrity verification after restoration operations
• Backup scheduling and retention policy implementation

---

**Document Version:** 1.0
**Last Updated:** 16/09/2025
**Next Review:** 16/12/2025

---

This comprehensive documentation provides complete technical and business guidance for the Sales Monitoring System, covering all aspects from architecture to troubleshooting across both Flutter mobile and Next.js web platforms.
````
