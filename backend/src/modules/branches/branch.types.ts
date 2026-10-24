export interface Branch {
  id: string;
  code: string;
  name: string;
  address: string | null;
  openingHours: string | null;
  latitude: number | null;
  longitude: number | null;
  geofenceRadiusM: number;
  isActive: boolean;
  /** Only returned to staff. */
  qrVersion?: string | null;
}
