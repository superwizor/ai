-- Migration 000080: crm_test_users table for marking test/team accounts in CRM
CREATE TABLE IF NOT EXISTS crm_test_users (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    marked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT
);

-- Initial seed of team and known test/disposable domains
INSERT INTO crm_test_users (user_id, reason)
SELECT id, 'auto: team/test/disposable domain'
FROM users
WHERE email IN (
    'theatlantahomes@gmail.com',
    'dpiotrak2@gmail.com',
    'dariusz.piotrak@ailiscare.com'
)
OR email LIKE '%@superwizor.ai'
OR email LIKE '%@example.com'
OR email LIKE '%@superwizor.test'
OR email LIKE '%@test.pl'
OR email LIKE '%@example.test'
OR email LIKE 'kolodzmaciej%'
OR email LIKE '%@doefy.com'
OR email LIKE '%@ezimb.com'
OR email LIKE '%@kinws.com'
OR email LIKE '%@fishnone.com'
OR email LIKE '%@ruutukf.com'
OR email LIKE '%@denipl.com'
OR email LIKE '%@hidingmail.net'
OR email LIKE '%@doreact.com'
OR email LIKE '%@alf5.com'
OR email LIKE '%@04.tml.waw.pl'
ON CONFLICT (user_id) DO NOTHING;
