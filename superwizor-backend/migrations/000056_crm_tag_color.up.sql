-- Migration 000056: Add color column to crm_tags for colored tag support.
ALTER TABLE crm_tags ADD COLUMN color TEXT NOT NULL DEFAULT '';
