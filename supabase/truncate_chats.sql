-- Truncate all chat-related tables
-- Run this in your Supabase Dashboard SQL Editor to clear all chat history

TRUNCATE TABLE messages, chat_participants, chats CASCADE;
