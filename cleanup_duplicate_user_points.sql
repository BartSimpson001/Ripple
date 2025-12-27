-- ============================
-- Clean up duplicate user_points entries
-- ============================
-- This script removes duplicate entries, keeping only the best record per user_id

-- Step 1: Check for duplicates first
SELECT user_id, COUNT(*) as count
FROM user_points
GROUP BY user_id
HAVING COUNT(*) > 1;
-- Run this first to see how many duplicates exist

-- Step 2: Delete duplicate records, keeping only the best one for each user_id
-- Keep the record with: highest total_points, or if equal, most recent updated_at, or if equal, earliest created_at
DELETE FROM user_points
WHERE id NOT IN (
    SELECT DISTINCT ON (user_id) id
    FROM user_points
    ORDER BY user_id, total_points DESC, updated_at DESC, created_at ASC
);

-- Step 3: Add unique constraint to prevent future duplicates
-- First, check if constraint already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'unique_user_id' 
        AND conrelid = 'user_points'::regclass
    ) THEN
        ALTER TABLE user_points ADD CONSTRAINT unique_user_id UNIQUE (user_id);
        RAISE NOTICE 'Unique constraint added successfully';
    ELSE
        RAISE NOTICE 'Unique constraint already exists';
    END IF;
END $$;

-- Step 4: Verify cleanup - should return no rows
SELECT user_id, COUNT(*) as count
FROM user_points
GROUP BY user_id
HAVING COUNT(*) > 1;
-- If this returns no rows, cleanup was successful!

-- Step 5: Show final count
SELECT COUNT(*) as total_users, 
       SUM(total_points) as total_points_sum
FROM user_points;

