-- Truncate all bounty and chat related tables
-- This effectively resets the app's dynamic content for testing
-- CAUTION: This deletes all data in these tables

TRUNCATE TABLE 
    messages, 
    chat_participants, 
    chats, 
    bounty_applications, 
    bounties 
CASCADE;
