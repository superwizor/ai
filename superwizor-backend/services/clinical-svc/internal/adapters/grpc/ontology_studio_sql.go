package grpc

// Zapytania Ontology Studio.
//
// Trzymane w osobnym pliku jak w admin_chat_controls.go: reguly
// przejsc statusow czyta sie inaczej niz SQL, a mieszanie jednego z
// drugim utrudnia audyt obu.
//
// Wszedzie liczymy construct_count po stronie bazy
// (jsonb_object_keys), zeby lista wersji nie wymagala parsowania YAML
// dla kazdego wiersza.

const ontologyVersionColumns = `
	ov.id, ov.modality_id, ov.version, ov.content #>> '{}' AS content_yaml,
	ov.status::text,
	COALESCE(cu.email, ''), ov.created_at, ov.change_note,
	au.email, ov.approved_at, ov.approval_note,
	(m.active_ontology_version_id = ov.id) AS is_active,
	COALESCE((SELECT count(*) FROM jsonb_object_keys(
		COALESCE(ov.content -> 'constructs', '{}'::jsonb))), 0)::int AS construct_count`

const sqlOntologyVersions = `
SELECT` + ontologyVersionColumns + `
  FROM ontology_versions ov
  JOIN modalities m ON m.id = ov.modality_id
  LEFT JOIN users cu ON cu.id = ov.created_by
  LEFT JOIN users au ON au.id = ov.approved_by
 WHERE ov.modality_id = $1
 ORDER BY ov.created_at DESC
 LIMIT $2 OFFSET $3`

const sqlOntologyVersionByID = `
SELECT` + ontologyVersionColumns + `
  FROM ontology_versions ov
  JOIN modalities m ON m.id = ov.modality_id
  LEFT JOIN users cu ON cu.id = ov.created_by
  LEFT JOIN users au ON au.id = ov.approved_by
 WHERE ov.id = $1`

// sqlOntologyModalities daje przeglad: co jest aktywne, ile draftow
// czeka, ile wersji jest w przegladzie.
const sqlOntologyModalities = `
SELECT m.id, m.system_code, m.display_name,
       av.version, av.id::text, latest.version,
       COALESCE(cnt.drafts, 0)::int, COALESCE(cnt.reviews, 0)::int
  FROM modalities m
  LEFT JOIN ontology_versions av ON av.id = m.active_ontology_version_id
  LEFT JOIN LATERAL (
      SELECT version FROM ontology_versions
       WHERE modality_id = m.id
       ORDER BY created_at DESC LIMIT 1
  ) latest ON TRUE
  LEFT JOIN LATERAL (
      SELECT count(*) FILTER (WHERE status = 'draft')            AS drafts,
             count(*) FILTER (WHERE status = 'ready_for_review') AS reviews
        FROM ontology_versions WHERE modality_id = m.id
  ) cnt ON TRUE
 ORDER BY m.system_code`

// sqlOntologyLockVersion serializuje przejscia statusu.
//
// FOR UPDATE jak w GetLatestModalityPromptVersion: dwa rownolegle
// zatwierdzenia tej samej wersji musza zostac rozstrzygniete
// deterministycznie, a nie wygrac wyscigiem.
const sqlOntologyLockVersion = `
SELECT ov.status::text, ov.created_by, ov.modality_id, ov.version
  FROM ontology_versions ov
 WHERE ov.id = $1
 FOR UPDATE`

const sqlOntologyInsertDraft = `
INSERT INTO ontology_versions
    (modality_id, version, content, status, created_by, change_note)
VALUES ($1, $2, $3::jsonb, 'draft', $4, $5)
RETURNING id`

// sqlOntologyUpdateDraft celowo ma `AND status = 'draft'` w WHERE.
//
// Trigger w bazie broni tresci wersji approved, ale wersja
// ready_for_review nie jest nim objeta — a edycja w trakcie przegladu
// oznaczalaby, ze zatwierdzajacy widzial co innego, niz zatwierdza.
// Zero wierszy = wolajacy dostaje FailedPrecondition.
const sqlOntologyUpdateDraft = `
UPDATE ontology_versions
   SET content = $2::jsonb, change_note = $3
 WHERE id = $1 AND status = 'draft'`

const sqlOntologySubmit = `
UPDATE ontology_versions
   SET status = 'ready_for_review', submitted_at = now(), change_note = $2
 WHERE id = $1 AND status = 'draft'`

// sqlOntologyApprove niesie four-eyes w WHERE, nie tylko w kodzie Go.
// CHECK w schemacie lapie to samo — celowe dublowanie, bo ta wlasnosc
// zastapila approvera z CODEOWNERS.
const sqlOntologyApprove = `
UPDATE ontology_versions
   SET status = 'approved', approved_by = $2, approved_at = now(), approval_note = $3
 WHERE id = $1 AND status = 'ready_for_review' AND created_by <> $2`

const sqlOntologyReject = `
UPDATE ontology_versions
   SET status = 'draft', submitted_at = NULL, approval_note = $2
 WHERE id = $1 AND status = 'ready_for_review'`

// sqlOntologyActivate ustawia wersje serwowana na produkcji.
//
// Warunek statusu jest w zapytaniu, nie tylko w kodzie: aktywacja jest
// ostatnia bramka przed generowaniem raportow dla realnych klientow.
const sqlOntologyActivate = `
UPDATE modalities m
   SET active_ontology_version_id = ov.id
  FROM ontology_versions ov
 WHERE ov.id = $1 AND ov.modality_id = m.id AND ov.status = 'approved'`
