// Supabase client. The anon key is PUBLIC by design — safe in the browser
// because Row Level Security controls what it can actually touch. The secret
// (service_role) key is NEVER here.
const SUPABASE_URL = "https://nnyomecbumnofqabvfmu.supabase.co";
const SUPABASE_ANON = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ueW9tZWNidW1ub2ZxYWJ2Zm11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzOTE1ODYsImV4cCI6MjA5Nzk2NzU4Nn0.ACAga1hbXZoH_cntBZk0u1Z67E3xVjaA_iBq2vM-6KU";
window.sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON);
