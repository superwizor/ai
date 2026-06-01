-- 000041 — email_templates (docs/22)
--
-- DB-backed, editable e-mail templates. notification-svc reads a row here
-- first and falls back to its embedded go:embed default if the row is missing
-- — so the service is safe to deploy before seeding, and templates can be
-- edited via SQL (or a future admin UI) without a code change.
--
-- content is a JSON object: {subject, body_html, body_text}. Placeholders use
-- the existing {key} convention (rendered by the i18n templater):
--   {patient_name} {therapist_name} {action_plan} {session_date}
-- The caller HTML-escapes/линkifies {action_plan} (newlines → <br>) before
-- substitution.

CREATE TABLE email_templates (
    template_key  TEXT NOT NULL,
    locale        TEXT NOT NULL,
    content       JSONB NOT NULL,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (template_key, locale)
);

INSERT INTO email_templates (template_key, locale, content) VALUES
('action_plan', 'pl', jsonb_build_object(
    'subject', 'Twój plan działania',
    'body_html', '<p>Dzień dobry,</p><p>Twój terapeuta {therapist_name} przesyła plan działania uzgodniony podczas sesji ({session_date}):</p><div style="padding:12px 16px;border-left:3px solid #E8A33D;background:#f6f6f4;">{action_plan}</div><p style="color:#888;font-size:12px;margin-top:24px;">Wiadomość wysłana za pośrednictwem Superwizor AI na prośbę Twojego terapeuty. Nie udostępniaj jej osobom trzecim.</p>',
    'body_text', E'Dzień dobry,\n\nTwój terapeuta {therapist_name} przesyła plan działania uzgodniony podczas sesji ({session_date}):\n\n{action_plan}\n\n— Wiadomość wysłana za pośrednictwem Superwizor AI na prośbę Twojego terapeuty.'
)),
('action_plan', 'en', jsonb_build_object(
    'subject', 'Your action plan',
    'body_html', '<p>Hello,</p><p>Your therapist {therapist_name} is sending you the action plan agreed during your session ({session_date}):</p><div style="padding:12px 16px;border-left:3px solid #E8A33D;background:#f6f6f4;">{action_plan}</div><p style="color:#888;font-size:12px;margin-top:24px;">Sent via Superwizor AI at your therapist''s request. Please do not share with third parties.</p>',
    'body_text', E'Hello,\n\nYour therapist {therapist_name} is sending you the action plan agreed during your session ({session_date}):\n\n{action_plan}\n\n— Sent via Superwizor AI at your therapist''s request.'
));
