-- Calorie entries table to store user calorie activities
CREATE TABLE IF NOT EXISTS public.calorie_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    calories INTEGER NOT NULL,
    is_gained BOOLEAN NOT NULL,
    post_id TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster querying by user_id
CREATE INDEX IF NOT EXISTS idx_calorie_entries_user_id ON public.calorie_entries(user_id);

-- Index for faster date-based queries
CREATE INDEX IF NOT EXISTS idx_calorie_entries_date ON public.calorie_entries(date);

-- Row level security policies
ALTER TABLE public.calorie_entries ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to select only their own entries
CREATE POLICY select_own_calorie_entries ON public.calorie_entries
    FOR SELECT USING (auth.uid() = user_id);

-- Policy to allow users to insert only their own entries
CREATE POLICY insert_own_calorie_entries ON public.calorie_entries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy to allow users to update only their own entries
CREATE POLICY update_own_calorie_entries ON public.calorie_entries
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy to allow users to delete only their own entries
CREATE POLICY delete_own_calorie_entries ON public.calorie_entries
    FOR DELETE USING (auth.uid() = user_id);
