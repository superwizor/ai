UPDATE users
SET deleted_at = NOW()
WHERE phone_number IN (
    SELECT phone_number 
    FROM users 
    WHERE deleted_at IS NULL 
    GROUP BY phone_number 
    HAVING COUNT(*) > 1
) 
AND email != 'maciej@euphire.pl' 
AND deleted_at IS NULL;
