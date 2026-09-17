export type Status = 'received' | 'opened' | 'dispatched' | 'resolved' | 'cancelled';
export interface QueueItem {
  id: string; protocol: string; category: string; description: string;
  latitude: number; longitude: number; accuracy_m: number | null;
  status: Status; effective_priority: number; ordering_reason: string;
  ai_rationale: string | null; created_at: string; received_at: string;
  hard_rule_priority: number; escalation_priority: number;
  is_test: boolean; location_source: 'gps' | 'manually_adjusted' | 'test_address';
  ai_suggested_priority: number | null; confirmed_priority: number | null;
}
