// TypeScript interfaces for the Advanced Sales API

export interface SalesFilters {
  // Date filters
  dateFrom?: string;
  dateTo?: string;
  createdFrom?: string;
  createdTo?: string;
  salesDateFrom?: string;
  salesDateTo?: string;

  // Location filters
  state?: string;
  states?: string[];
  city?: string;
  cities?: string[];
  lga?: string;
  lgas?: string[];
  country?: string;

  // Product/Stove filters
  stoveSerialNo?: string;
  stoveSerialNos?: string[];
  stoveSerialNoPattern?: string;

  // People filters
  contactPerson?: string;
  contactPhone?: string;
  endUserName?: string;
  aka?: string;
  partnerName?: string;
  createdBy?: string;
  createdByIds?: string[];

  // Amount filters
  amountMin?: number;
  amountMax?: number;
  amountExact?: number;
  amountRange?: { min: number; max: number };

  // Status filters
  status?: string;
  statuses?: string[];

  // Organization filters
  organizationId?: string;
  organizationIds?: string[];

  // Phone filters
  phone?: string;
  otherPhone?: string;
  anyPhone?: string;

  // Text search filters
  search?: string;
  searchFields?: string[];

  // Advanced filters
  hasStoveImage?: boolean;
  hasAgreementImage?: boolean;
  hasSignature?: boolean;
  hasAddress?: boolean;

  // Geolocation filters
  nearLocation?: {
    latitude: number;
    longitude: number;
    radiusKm: number;
  };

  // Pagination
  page?: number;
  limit?: number;
  offset?: number;

  // Sorting
  sortBy?: string;
  sortOrder?: "asc" | "desc";
  multiSort?: Array<{ field: string; order: "asc" | "desc" }>;

  // Export options
  export?: "csv" | "json" | "xlsx";
  exportFields?: string[];

  // Data inclusion options
  includeAddress?: boolean;
  includeImages?: boolean;
  includeCreator?: boolean;
  includeOrganization?: boolean;
  includeSalesHistory?: boolean;

  // Time-based filters
  lastNDays?: number;
  thisWeek?: boolean;
  thisMonth?: boolean;
  thisYear?: boolean;
  lastWeek?: boolean;
  lastMonth?: boolean;
  lastYear?: boolean;

  // Advanced date queries
  dayOfWeek?: number;
  monthOfYear?: number;
  quarter?: number;
}

export interface Address {
  id: string;
  city?: string;
  state?: string;
  street?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
  full_address?: string;
  created_at?: string;
}

export interface ImageData {
  id: string;
  url?: string;
  type?: string;
  public_id?: string;
  created_at?: string;
}

export interface UserProfile {
  id: string;
  full_name?: string;
  email?: string;
  phone?: string;
  role?: string;
}

export interface Organization {
  id: string;
  name?: string;
  type?: string;
  address?: string;
  contact_info?: any;
}

export interface SalesHistory {
  id: string;
  action_type?: string;
  action_description?: string;
  field_changes?: any;
  performed_at?: string;
  performed_by?: string;
}

export interface Sale {
  id: string;
  transaction_id?: string;
  stove_serial_no?: string;
  sales_date?: string;
  contact_person?: string;
  contact_phone?: string;
  end_user_name?: string;
  aka?: string;
  state_backup?: string;
  lga_backup?: string;
  phone?: string;
  other_phone?: string;
  partner_name?: string;
  amount: number;
  signature?: string;
  status?: string;
  created_by?: string;
  organization_id?: string;
  address_id?: string;
  stove_image_id?: string;
  agreement_image_id?: string;
  created_at?: string;

  // Related data (when included)
  address?: Address;
  stove_image?: ImageData;
  agreement_image?: ImageData;
  creator?: UserProfile;
  organization?: Organization;
  sales_history?: SalesHistory[];
}

export interface PaginationInfo {
  page: number;
  limit: number;
  offset: number;
  total: number;
  totalPages: number;
}

export interface SalesResponse {
  success: boolean;
  data?: Sale[];
  pagination?: PaginationInfo;
  filters?: SalesFilters;
  timestamp?: string;
  message?: string;
  error?: string;
}

// React Hook Example
import { useState, useCallback } from "react";

export const useSalesData = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<Sale[]>([]);
  const [pagination, setPagination] = useState<PaginationInfo | null>(null);

  const fetchSales = useCallback(
    async (filters: SalesFilters, token: string): Promise<SalesResponse> => {
      setLoading(true);
      setError(null);

      try {
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

        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result: SalesResponse = await response.json();

        if (result.success && result.data) {
          setData(result.data);
          setPagination(result.pagination || null);
        } else {
          setError(result.message || "Failed to fetch sales data");
        }

        return result;
      } catch (err) {
        const errorMessage =
          err instanceof Error ? err.message : "Unknown error";
        setError(errorMessage);
        return {
          success: false,
          message: errorMessage,
        };
      } finally {
        setLoading(false);
      }
    },
    []
  );

  const exportSales = useCallback(
    async (
      filters: SalesFilters & { export: "csv" | "json" | "xlsx" },
      token: string
    ): Promise<string | Blob> => {
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

      if (!response.ok) {
        throw new Error(`Export failed: ${response.status}`);
      }

      if (filters.export === "csv") {
        return await response.text();
      } else {
        return await response.blob();
      }
    },
    []
  );

  return {
    loading,
    error,
    data,
    pagination,
    fetchSales,
    exportSales,
  };
};

// Usage Example Component
import React, { useEffect, useState } from "react";

const SalesDataTable: React.FC = () => {
  const { loading, error, data, pagination, fetchSales, exportSales } =
    useSalesData();
  const [filters, setFilters] = useState<SalesFilters>({
    page: 1,
    limit: 50,
    sortBy: "created_at",
    sortOrder: "desc",
    includeAddress: true,
    includeCreator: true,
  });

  useEffect(() => {
    const token = localStorage.getItem("supabase_token"); // Or however you store the token
    if (token) {
      fetchSales(filters, token);
    }
  }, [filters, fetchSales]);

  const handleFilterChange = (newFilters: Partial<SalesFilters>) => {
    setFilters((prev) => ({ ...prev, ...newFilters, page: 1 }));
  };

  const handleExport = async () => {
    try {
      const token = localStorage.getItem("supabase_token");
      if (!token) return;

      const csvData = await exportSales(
        {
          ...filters,
          export: "csv",
          exportFields: [
            "stove_serial_no",
            "end_user_name",
            "amount",
            "sales_date",
            "state_backup",
          ],
        },
        token
      );

      // Create download link
      const blob = new Blob([csvData as string], { type: "text/csv" });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "sales-export.csv";
      a.click();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      console.error("Export failed:", err);
    }
  };

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <div>
      {/* Filter Controls */}
      <div className="filters">
        <input
          type="text"
          placeholder="Search..."
          onChange={(e) => handleFilterChange({ search: e.target.value })}
        />

        <select onChange={(e) => handleFilterChange({ state: e.target.value })}>
          <option value="">All States</option>
          <option value="Lagos">Lagos</option>
          <option value="Abuja">Abuja</option>
          <option value="Kano">Kano</option>
        </select>

        <input
          type="number"
          placeholder="Min Amount"
          onChange={(e) =>
            handleFilterChange({ amountMin: Number(e.target.value) })
          }
        />

        <button onClick={handleExport}>Export CSV</button>
      </div>

      {/* Data Table */}
      <table>
        <thead>
          <tr>
            <th>Stove Serial</th>
            <th>End User</th>
            <th>Amount</th>
            <th>State</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {data.map((sale) => (
            <tr key={sale.id}>
              <td>{sale.stove_serial_no}</td>
              <td>{sale.end_user_name}</td>
              <td>{sale.amount}</td>
              <td>{sale.state_backup}</td>
              <td>{sale.sales_date}</td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* Pagination */}
      {pagination && (
        <div className="pagination">
          <button
            disabled={pagination.page === 1}
            onClick={() => handleFilterChange({ page: pagination.page - 1 })}
          >
            Previous
          </button>

          <span>
            Page {pagination.page} of {pagination.totalPages}
          </span>

          <button
            disabled={pagination.page === pagination.totalPages}
            onClick={() => handleFilterChange({ page: pagination.page + 1 })}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
};

export default SalesDataTable;
