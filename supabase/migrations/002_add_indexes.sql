-- Students indexes
create index if not exists idx_students_email on public.students (email);
create index if not exists idx_students_created_at on public.students (created_at);
create index if not exists idx_students_first_last on public.students (first_name, last_name);
create index if not exists idx_students_seat on public.students (seat_number);

-- Subscriptions indexes
create index if not exists idx_subscriptions_student on public.subscriptions (student_id);
create index if not exists idx_subscriptions_status on public.subscriptions (status);
create index if not exists idx_subscriptions_end_date on public.subscriptions (end_date);
create index if not exists idx_subscriptions_created_at on public.subscriptions (created_at);

-- Activity logs indexes
create index if not exists idx_activity_logs_entity on public.activity_logs (entity_id, entity_type);
create index if not exists idx_activity_logs_timestamp on public.activity_logs (timestamp);

