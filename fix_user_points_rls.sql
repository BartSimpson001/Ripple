-- ============================
-- Fix RLS for user_points and point_history tables
-- ============================

-- Option 1: Disable RLS (Recommended for Firebase Auth)
-- Run this if you want to disable RLS completely
ALTER TABLE user_points DISABLE ROW LEVEL SECURITY;
ALTER TABLE point_history DISABLE ROW LEVEL SECURITY;

-- Option 2: Enable RLS with proper policies (if you want to keep RLS enabled)
-- Uncomment the lines below if you prefer to use RLS policies instead

-- First, enable RLS
-- ALTER TABLE user_points ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE point_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
-- DROP POLICY IF EXISTS "Anyone can view user_points" ON user_points;
-- DROP POLICY IF EXISTS "Anyone can insert user_points" ON user_points;
-- DROP POLICY IF EXISTS "Anyone can update user_points" ON user_points;
-- DROP POLICY IF EXISTS "Anyone can view point_history" ON point_history;
-- DROP POLICY IF EXISTS "Anyone can insert point_history" ON point_history;

-- Create policies for user_points
-- CREATE POLICY "Anyone can view user_points"
--   ON user_points FOR SELECT
--   USING (true);

-- CREATE POLICY "Anyone can insert user_points"
--   ON user_points FOR INSERT
--   WITH CHECK (true);

-- CREATE POLICY "Anyone can update user_points"
--   ON user_points FOR UPDATE
--   USING (true)
--   WITH CHECK (true);

-- Create policies for point_history
-- CREATE POLICY "Anyone can view point_history"
--   ON point_history FOR SELECT
--   USING (true);

-- CREATE POLICY "Anyone can insert point_history"
--   ON point_history FOR INSERT
--   WITH CHECK (true);

