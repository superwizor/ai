# Data Processing Agreement (DPA)

**Effective Date:** 2026-06-12

This Data Processing Agreement ("**DPA**" or "**Agreement**") is entered into between: 

**The Professional User**, who has accepted the Terms of Service of the Superwizor AI application, acting as: **Data Controller** (hereinafter referred to as the "**Controller**") 

and 

**Euphire sp. z o.o.** with its registered office at ul. Odrzańska 10a/48 in Kraków, entered into the register of entrepreneurs of the National Court Register under KRS number 0000907254, NIP: 6793219020, acting as: **Data Processor** (hereinafter referred to as the "**Processor**" or "**Service Provider**") 

hereinafter collectively referred to as the "**Parties**".

---

## PREAMBLE

*   **WHEREAS**, the Controller has concluded an agreement with the Processor for the provision of electronic services by accepting the Terms of Service of the Superwizor AI application (hereinafter the "Terms" or "Main Agreement"), available in the "Legal Information" section of the App settings; 
*   **WHEREAS**, as part of the services specified in the Main Agreement, the Controller entrusts the Processor with processing the personal data of their Patients and other persons participating in sessions, including special categories of data (health data); 
*   **WHEREAS**, this DPA fulfills the legal obligation specified in Art. 28 sec. 3 of Regulation (EU) 2016/679 of the European Parliament and of the Council of 27 April 2016 ("GDPR"); 
*   **WHEREAS**, this DPA is an integral part of the Main Agreement. 

> Acceptance of the Terms by checking the appropriate checkbox during registration in the Application is equivalent to the acceptance and conclusion of this DPA in electronic (documented) form, in accordance with Art. 28 sec. 9 GDPR. 

The Parties agree as follows:

---

## § 1. DEFINITIONS

1.  Capitalized terms not defined in this DPA have the meaning assigned to them in the Terms. 
2.  **Privacy Policy** – a document specifying the rules of data processing by the Service Provider, available in the "Legal Information" section of the App settings. 
3.  **Personal Data** – all personal data of the Controller's Patients and other persons participating in sessions (e.g., partners in couples therapy, family members), including special categories of personal data (data concerning physical and mental health), processed by the Processor on behalf of the Controller in connection with the performance of the Main Agreement. 
4.  **Personal Data Breach** – a breach of security leading to the accidental or unlawful destruction, loss, alteration, unauthorized disclosure of, or unauthorized access to Personal Data. 
5.  **Third Country** – a country outside the European Economic Area (EEA).

---

## § 2. SUBJECT, SCOPE AND PURPOSE OF PROCESSING

1.  The Controller entrusts the Processor with Personal Data for processing on the terms and for the purpose specified in this Agreement. 
2.  **Subject of processing:** Performance of services provided by the Processor under the Main Agreement, consisting of processing audio recordings of therapy and coaching sessions, their transcription, analysis using artificial intelligence, and generation of clinical reports. 
3.  **Nature and purpose of processing:** Performing operations on Personal Data necessary to provide the Application services to the Controller, in accordance with the functionalities described in § 4 of the Terms, in particular: 
    *   Temporary storage of audio recordings (the recording is deleted immediately after successful transcription, and at the latest by an automatic cleanup mechanism triggered 48 hours after upload).
    *   Automatic transcription of audio recordings using Speech-to-Text technology (Chirp 3).
    *   Diarization (identification and differentiation of speakers) together with automatic assignment of labels describing the speaker's role in the conversation (e.g., "Therapist", "Patient", or in coaching sessions "Coach", "Client") or neutral labels (e.g., "Person 1") when the role cannot be determined; labels do not contain first or last names and may be corrected by the Controller.
    *   Generation of structured clinical reports using artificial intelligence (Vertex AI / Gemini).
    *   Generation of HiTOP dimensional measurements.
    *   Creation and storage of encrypted clinical memory (RAG) — pseudonymized (stripped of direct identifiers) session summaries and related thematic threads to ensure therapeutic continuity.
    *   Generation of embeddings (vector representations) for clinical memory.
    *   Storage of encrypted transcriptions and reports as User Materials.
4.  **Type of Personal Data:** Data specified in Part II of the Privacy Policy ("Information for Patients"), in particular: 
    *   Identification and contact data, insofar as they appear in the recording or transcription. 
    *   Special categories of Personal Data, i.e., data concerning the physical or mental health of Patients (Art. 9 sec. 1 of the GDPR). 
    *   Any other Personal Data contained in audio recordings, their transcriptions, clinical reports, and clinical memory. 
5.  **Categories of data subjects:** Patients of the Controller, as defined in § 2 point 9 of the Terms, as well as other persons participating in recorded sessions (e.g., a partner in couples therapy, family members, guardians). 
6.  **Duration of processing:** Personal Data will be processed for the duration of the Main Agreement, in accordance with § 13 of the Terms, subject to the following:
    *   Audio recordings are deleted immediately after successful transcription, and at the latest by the automatic cleanup mechanism triggered 48 hours after upload (regardless of the Agreement status).
    *   After termination of the Main Agreement, remaining Personal Data (transcriptions, reports, clinical memory) is marked as deleted (soft delete) and permanently deleted after 30 days, as part of a recurring permanent data deletion process.

---

## § 3. OBLIGATIONS OF THE PROCESSOR

The Processor undertakes to: 

1.  **Process on instructions:** Process Personal Data only on documented instructions from the Controller — unless processing is required by Union or Member State law to which the Processor is subject; in such a case, the Processor shall inform the Controller of that legal requirement before processing, unless that law prohibits such information. Documented instructions include the provisions of the Main Agreement and this DPA, as well as ongoing actions and configurations made by the Controller in the Application (e.g., initiating a session recording, creating a Patient file, setting report preferences, correcting speaker labels). 
2.  **Confidentiality:** Ensure that persons authorized to process the Personal Data have committed themselves to confidentiality or are under an appropriate statutory obligation of confidentiality. 
3.  **Security of processing (Art. 32 GDPR):** Implement and apply appropriate technical and organizational measures to ensure a level of security appropriate to the risk, in particular as described in Part I, point 5 of the Privacy Policy, including:
    *   Envelope encryption of special categories of data at the application level and CMEK keys managed in Cloud KMS with automatic rotation every 90 days.
    *   Storage and processing of Personal Data exclusively within the EEA: the europe-central2 region (Warsaw) and — for AI services — europe-west4 (Netherlands); resource locations are defined in infrastructure-as-code configuration subject to version control.
    *   Database access over encrypted channels from a private VPC network, with direct access restricted to a controlled list of authorized administrative addresses.
    *   Dedicated Service Accounts with minimum permissions for each microservice.
    *   Deletion of audio recordings immediately after transcription, at the latest by the automatic mechanism (OLM) after 48 hours.
    *   Soft-delete mechanism with permanent deletion after a 30-day retention period, performed by a recurring permanent deletion process.
    *   Audit logging of all significant data operations.
4.  **Assist the Controller:** Assist the Controller by appropriate measures, insofar as this is possible, for the fulfillment of the Controller's obligation to respond to requests for exercising the data subject's rights, in particular regarding the right to access, rectification, erasure, and data portability. 
5.  **Support the Controller:** Assist the Controller in ensuring compliance with the obligations pursuant to Articles 32 to 36 of the GDPR (security, impact assessment, consultation with supervisory authority), taking into account the nature of processing and the information available to the Processor. 
6.  **Report breaches:** Notify the Controller without undue delay after becoming aware of a Personal Data Breach, no later than within **48 hours** of detecting the breach. The notification will include at least: a description of the nature of the breach, the categories and approximate number of data subjects affected, the likely consequences of the breach, and the measures taken or proposed to address the breach. 
7.  **Delete or return data:** At the choice of the Controller, delete or return all the Personal Data to the Controller after the end of the provision of services relating to processing (termination of the Main Agreement), and delete existing copies unless law requires storage of the personal data. The data deletion procedure after agreement termination is as follows:
    *   **Audio recordings:** deleted immediately after transcription, at the latest by the automatic mechanism triggered 48 hours after upload (regardless of Agreement status) — no action required.
    *   **Transcriptions, reports, HiTOP measurements, RAG clinical memory:** marked as deleted (soft delete) and permanently deleted from the database after 30 days, as part of the recurring permanent deletion process.
    *   **Patient file data:** deleted cascadingly with the User's account, subject to the 30-day soft-delete retention period.
    *   **Encrypted backups:** data may be present in encrypted Cloud SQL backups for the duration of their retention period (no longer than 30 days), after which they are automatically overwritten. Without access to Cloud KMS, data in backups remains unreadable.
    *   **Encryption keys:** KEK rotation (every 90 days) renders encrypted DEKs from previous key versions unusable after the cryptographic material of older versions is deleted.
8.  **Audit:** Make available to the Controller all information necessary to demonstrate compliance with the obligations laid down in Article 28 GDPR and allow for and contribute to audits. Detailed audit rules are as follows: 
    *   The Parties agree that in order to minimize operational disruptions, the Controller accepts in the first instance the provision by the Processor of its own security assessment report, documentation of technical and organizational measures, and, where available, certificates or attestations (e.g., ISO 27001, SOC 2) or audit reports conducted by independent third parties. As of the effective date of this DPA, the Processor does not hold ISO 27001 or SOC 2 certifications; however, its infrastructure is based on Google Cloud Platform, which holds ISO 27001, ISO 27017, ISO 27018, and SOC 1/2/3 certifications.
    *   If the provided information is insufficient, the Controller has the right to conduct an audit by informing the Processor at least 30 days in advance. The audit will be conducted during the Processor's working hours, in a manner that causes minimal disruption to its business. The Controller bears all costs associated with conducting the audit, including the auditor's fees.

---

## § 4. OBLIGATIONS OF THE CONTROLLER

The Controller declares and warrants that: 

1.  It processes Personal Data in accordance with the law, including the GDPR and the Data Protection Act. 
2.  It has an appropriate legal basis for processing the Personal Data of Patients and entrusting them to the Processor, in accordance with the obligation described in § 5 of the Terms. In particular, for the processing of health data (Art. 9 sec. 1 GDPR), the Controller ensures fulfillment of a condition under Art. 9 sec. 2 GDPR (e.g., point (h) in connection with the exercise of a profession subject to professional secrecy, or explicit consent — point (a), in particular where the Controller does not practice a profession subject to statutory secrecy, e.g., in the case of coaching services).
3.  It has fulfilled the information obligation towards data subjects (in accordance with Art. 13 or 14 of the GDPR), including informing Patients and all other persons participating in the session about the recording of sessions and the use of the App. The Processor provides in Part II of the Privacy Policy model information that can be used by the Controller to support them in fulfilling this obligation.
4.  It will only issue lawful instructions to the Processor regarding the processing of Personal Data.
5.  It complies with the rules of professional secrecy applicable to its profession, arising in particular from the Act on the Professions of Physician and Dentist, the Act on the Profession of Psychologist and the Professional Self-Government of Psychologists, the Act on the Profession of Psychotherapist, and professional codes of ethics.

---

## § 5. SUB-PROCESSING AND DATA TRANSFER

1.  **General authorization for sub-processing:** The Controller grants general written authorization (Art. 28 sec. 2 GDPR) for the Processor to use the services of Sub-processors listed in sec. 2. 
2.  **List of Sub-processors:** The Processor undertakes to maintain an up-to-date list of Sub-processors participating in the processing of Personal Data (Patients' data). As of the effective date of this DPA, the list of Sub-processors is as follows:

| Sub-processor | Service | Data Processed | Location |
|---|---|---|---|
| **Google Cloud Platform** (Google Cloud EMEA Ltd / Google LLC) | Cloud Run, Cloud SQL PostgreSQL, Cloud Storage, Cloud KMS, Pub/Sub, Secret Manager | Backend processing and storage of Personal Data | europe-central2 (Warsaw, Poland) |
| **Google Cloud — Vertex AI** | Speech-to-Text (Chirp 3), Gemini (reports), Text Embeddings (RAG) | Transcription, report generation, embeddings | europe-west4 (Netherlands) — EEA |
| **Google Firebase** | Cloud Firestore (mirrored session processing statuses — no clinical content), FCM (push notifications — no clinical content) | Pseudonymous session identifiers and processing statuses | Firestore: europe-central2; FCM: a global Google service (notification content does not contain Patients' Personal Data) |

    Providers processing exclusively Professional Users' data (in particular Stripe — payment processing, and Resend — sending e-mails to the User) do not process Patients' Personal Data and are not Sub-processors within the meaning of this DPA; they are listed in the Privacy Policy as recipients of Professional Users' data.

    The current list is also available in Part I, point 6 of the Privacy Policy.

3.  **Obligations upon sub-processing:** The Processor shall ensure that the contract with each Sub-processor imposes on them at least the same data protection obligations as set out in this DPA for the Processor. The Processor remains fully liable to the Controller for the performance of that Sub-processor's data protection obligations. 
4.  **Right to object:** The Processor will inform the Controller (by email to the address associated with the Account or via an in-App notification) of any intended changes concerning the addition or replacement of Sub-processors, thereby giving the Controller the opportunity to raise a justified objection to such changes within 14 days of receiving the information. In the event of a justified objection, the Parties will attempt to resolve the situation. If a resolution is not possible, the Controller has the right to terminate the Main Agreement.
5.  **No transfer of Personal Data to Third Countries:** The Processor guarantees that Patients' Personal Data (audio recordings, transcriptions, clinical reports, HiTOP measurements, clinical memory) **is not transferred to Third Countries** (outside the EEA). The infrastructure processing this data is located within the European Economic Area (region europe-central2 — Warsaw and region europe-west4 — Netherlands), and resource locations are defined in infrastructure-as-code configuration subject to version control and reviews.

---

## § 6. LIABILITY

1.  The liability of the Parties is governed by the provisions of the GDPR, in particular Art. 82. 
2.  The liability of the Processor is limited to damages resulting directly from its breach of obligations arising from this Agreement or the provisions of the GDPR directly applicable to Processors. 
3.  In accordance with § 8 of the Terms, the total liability of the Processor towards the Controller under this Agreement is limited to the amount of the Subscription Fees paid by the Controller in the 12 months preceding the event causing the damage. This limitation does not apply to liability arising from intentional misconduct or gross negligence.

---

## § 7. FINAL PROVISIONS

1.  This DPA is an integral part of the Main Agreement. In the event of any conflict between the provisions of the DPA and the Terms regarding personal data protection, the provisions of the DPA shall prevail. 
2.  The Agreement enters into force upon acceptance of the Main Agreement by the Controller and is valid for its entire duration, and with respect to data deletion obligations — until their full performance. 
3.  The rules for amending the DPA are analogous to the rules for amending the Terms, described in § 14 of the Terms. The Controller will be informed of any changes at least 14 days in advance. 
4.  In matters not covered by this Agreement, the provisions of the Terms and the Privacy Policy apply, followed by the provisions of Polish law and the GDPR. 
5.  The competent court for resolving disputes will be the court with local jurisdiction over the Processor's registered office in Kraków, in accordance with § 15 sec. 2 of the Terms.
