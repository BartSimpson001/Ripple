-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================
-- User Profiles Table
-- ============================
CREATE TABLE IF NOT EXISTS user_profiles (
  id TEXT PRIMARY KEY, -- Firebase UID
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================
-- Reports Table
-- ============================
CREATE TABLE IF NOT EXISTS reports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  contact TEXT,
  location TEXT NOT NULL,
  coords TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  image_url TEXT NOT NULL,
  status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Resolved', 'Rejected')),
  likes_count INTEGER DEFAULT 0,
  comments_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- Likes Table
-- ============================
CREATE TABLE IF NOT EXISTS likes (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(report_id, user_id)
);

-- ============================
-- Comments Table
-- ============================
CREATE TABLE IF NOT EXISTS comments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================
-- Indexes
-- ============================
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_likes_report_id ON likes(report_id);
CREATE INDEX IF NOT EXISTS idx_likes_user_id ON likes(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_report_id ON comments(report_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments(created_at);

-- ============================
-- Drop Old Triggers & Functions
-- ============================
DROP TRIGGER IF EXISTS trigger_likes_count ON likes;
DROP FUNCTION IF EXISTS trigger_update_likes_count();
DROP FUNCTION IF EXISTS update_likes_count(UUID);

DROP TRIGGER IF EXISTS trigger_comments_count ON comments;
DROP FUNCTION IF EXISTS trigger_update_comments_count();
DROP FUNCTION IF EXISTS update_comments_count(UUID);

-- ============================
-- Auto-update Functions
-- ============================
CREATE OR REPLACE FUNCTION update_likes_count(report_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE reports 
  SET likes_count = (
    SELECT COUNT(*) FROM likes WHERE report_id = update_likes_count.report_id
  ),
  updated_at = NOW()
  WHERE id = update_likes_count.report_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_comments_count(report_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE reports 
  SET comments_count = (
    SELECT COUNT(*) FROM comments WHERE report_id = update_comments_count.report_id
  ),
  updated_at = NOW()
  WHERE id = update_comments_count.report_id;
END;
$$ LANGUAGE plpgsql;

-- ============================
-- Trigger Functions
-- ============================
CREATE OR REPLACE FUNCTION trigger_update_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'DELETE' THEN
    PERFORM update_likes_count(COALESCE(NEW.report_id, OLD.report_id));
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trigger_update_comments_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'DELETE' THEN
    PERFORM update_comments_count(COALESCE(NEW.report_id, OLD.report_id));
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ============================
-- Create Triggers
-- ============================
CREATE TRIGGER trigger_likes_count
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_likes_count();

CREATE TRIGGER trigger_comments_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_update_comments_count();

-- ============================
-- Storage Bucket for Images
-- ============================
INSERT INTO storage.buckets (id, name, public, file_size_limit) 
VALUES ('reports', 'reports', true, 52428800)  -- 50MB
ON CONFLICT (id) DO NOTHING;

-- ============================
-- Disable RLS for Firebase Auth Compatibility
-- ============================
ALTER TABLE user_profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE reports DISABLE ROW LEVEL SECURITY;
ALTER TABLE likes DISABLE ROW LEVEL SECURITY;
ALTER TABLE comments DISABLE ROW LEVEL SECURITY;

-- ============================
-- Drop All Existing Policies
-- ============================
DROP POLICY IF EXISTS "Anyone can view reports" ON reports;
DROP POLICY IF EXISTS "Authenticated users can create reports" ON reports;
DROP POLICY IF EXISTS "Users can update their own reports" ON reports;
DROP POLICY IF EXISTS "Users can delete their own reports" ON reports;

DROP POLICY IF EXISTS "Anyone can view likes" ON likes;
DROP POLICY IF EXISTS "Authenticated users can like reports" ON likes;
DROP POLICY IF EXISTS "Users can unlike their own likes" ON likes;

DROP POLICY IF EXISTS "Anyone can view comments" ON comments;
DROP POLICY IF EXISTS "Authenticated users can comment" ON comments;
DROP POLICY IF EXISTS "Users can update their own comments" ON comments;
DROP POLICY IF EXISTS "Users can delete their own comments" ON comments;

DROP POLICY IF EXISTS "Anyone can view report images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload report images" ON storage.objects;
DROP POLICY IF EXISTS "Users can update images they uploaded" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete images they uploaded" ON storage.objects;

-- ============================
-- Safe Storage Policies
-- ============================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Public read access for report images' 
    AND tablename = 'objects'
  ) THEN
    CREATE POLICY "Public read access for report images"  
      ON storage.objects FOR SELECT  
      USING (bucket_id = 'reports');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Allow upload of report images' 
    AND tablename = 'objects'
  ) THEN
    CREATE POLICY "Allow upload of report images"  
      ON storage.objects FOR INSERT  
      WITH CHECK (bucket_id = 'reports');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Allow update of report images' 
    AND tablename = 'objects'
  ) THEN
    CREATE POLICY "Allow update of report images"  
      ON storage.objects FOR UPDATE  
      USING (bucket_id = 'reports');
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE policyname = 'Allow delete of report images' 
    AND tablename = 'objects'
  ) THEN
    CREATE POLICY "Allow delete of report images"  
      ON storage.objects FOR DELETE  
      USING (bucket_id = 'reports');
  END IF;
END
$$;

-- ============================
-- View: User Activity Summary
-- ============================
CREATE OR REPLACE VIEW user_activity_summary AS
SELECT 
  up.id AS user_id,
  r.id AS report_id,
  l.id AS like_id,
  c.id AS comment_id
FROM user_profiles up
LEFT JOIN reports r ON r.user_id = up.id
LEFT JOIN likes l ON l.user_id = up.id
LEFT JOIN comments c ON c.user_id = up.id;