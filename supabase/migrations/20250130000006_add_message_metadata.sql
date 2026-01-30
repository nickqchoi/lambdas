-- Add metadata column to messages table to store contextual info (e.g. bounty_id for system messages)
ALTER TABLE public.messages
ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}'::jsonb;

-- Comment for clarity
COMMENT ON COLUMN public.messages.metadata IS 'Contextual metadata for the message, e.g. {"bountyId": "uuid"} for system messages.';
