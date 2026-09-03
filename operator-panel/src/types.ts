export type Status = 'received' | 'opened' | 'dispatched' | 'resolved' | 'cancelled';
export interface QueueItem {
  id: string; protocol: string; category: string; description: string;
  latitude: number; longitude: number; accuracy_m: number | null;
  status: Status; effective_priority: number; ordering_reason: string;
  ai_rationale: string | null; created_at: string; received_at: string;
  hard_rule_priority: number; escalation_priority: number;
}
