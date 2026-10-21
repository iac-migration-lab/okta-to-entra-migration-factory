# Identity as Code Concepts Glossary

Plain-language definitions for the Okta to Microsoft Entra ID migration method.
Prepared by Mark Lencioni, October 12, 2026. Converted from PDF to Markdown 2026-10-18.

> **Note on this copy.** The repo is public and has nothing to do with any client. Facts in the original that described one specific organization (application counts, vendor stack, pilot group names, sync timings) are rewritten here in general terms. Where the glossary describes the **production design** (four repositories, ServiceNow, `iac-inventory-ro`), the lab uses simpler stand-ins; see [Lab names vs. design names](#lab-names-vs-design-names) at the end.

## Contents

- [How to use this glossary](#how-to-use-this-glossary)
- [Program and method concepts](#program-and-method-concepts)
- [Okta concepts](#okta-concepts)
- [Microsoft Entra ID concepts](#microsoft-entra-id-concepts)
- [Git and repositories](#git-and-repositories)
- [CI/CD, pipelines, and gates](#cicd-pipelines-and-gates)
- [Terraform and configuration files](#terraform-and-configuration-files)
- [Pipeline identities and access](#pipeline-identities-and-access)
- [Repositories, folders, and workflow files](#repositories-folders-and-workflow-files)
- [SailPoint, provisioning, and authoritative sources](#sailpoint-provisioning-and-authoritative-sources)
- [Governance, change management, and roles](#governance-change-management-and-roles)
- [FAQ](#faq)
- [Acronym quick reference](#acronym-quick-reference)
- [Lab names vs. design names](#lab-names-vs-design-names)

---

## How to use this glossary

This glossary defines the Identity as Code concepts used across the Okta to Microsoft Entra ID migration method and its design records, in plain language, for readers outside identity engineering. It is written for change managers, program and project managers, business sponsors, application owners, service desk leads, auditors, and directors of other disciplines.

Each entry follows the same pattern:

- **The term in bold**, followed by its full name where it is an acronym.
- **What it is**, in one or two plain sentences, often with an everyday comparison.
- **In this program:** how the term is used in the Okta to Entra ID migration specifically.
- **Why it matters to you:** included where the term changes what a non-technical role does, approves, or should expect.

Terms are grouped by subject, and entries are alphabetical within each section, so related ideas sit together and each term is easy to find. The acronym table at the end lists every abbreviation alphabetically with a pointer to its section. Names in `code font` are literal names of files, folders, identities, or settings that you will see in the repositories and design records.

Two ideas carry most of the program, and the rest of the glossary builds on them:

1. **The configuration is written down as files before it is built.** Every sign-in rule, application connection, and group is described in text files kept under version control, not clicked into an administrative screen.
2. **Only an automated, reviewed pipeline may change the live system.** People change the files; the pipeline checks, approves, and applies the change. Okta stays in place as the fallback until each moved application has been validated.

---

## Program and method concepts

**Brownfield import** — Bringing an existing, hand-built configuration under code management by recording it as files exactly as it stands, before changing anything. Success is measured by a **zero-change plan**: the tool confirms the files match the live system with nothing to change. *In this program:* existing Entra objects go into the `legacy/` folder with deletion protection on every item.

**Change-freeze monitor** — Using the nightly snapshot comparison to catch any change made in Okta during the migration. Okta is not technically locked, but every change becomes visible the next morning for review. *Why it matters to you:* if a team changes an Okta application mid-migration, the program knows within a day rather than discovering it at cutover.

**Cutover** — The moment an application or user group stops using Okta and starts using Entra ID for sign-in. *In this program:* cutover happens wave by wave, never all at once, and the Okta configuration is left in place as the fallback.

**Decision workbook (Conditional Access decision workbook)** — A worksheet produced from the brownfield import that lists each existing Entra sign-in policy with its actual usage, overlaps with other policies, and dependency on Okta. Security and IAM (Identity and Access Management) use it to decide whether to keep, rebuild, or merge each policy.

**Declarative configuration** — Stating the end result you want ("this policy exists, applies to these people, requires this sign-in method") rather than the steps to get there. The tool works out the steps itself, including doing nothing when the system already matches. The opposite is **manual configuration**: a person making changes one by one in the administrative console, sometimes called the portal.

**Decommission** — The final retirement of Okta after the last wave: assignments removed, contract exited. It has a hard date and a named executive owner so a long runway does not let it slip indefinitely.

**Disposition** — The decided fate of an object: migrate as is, migrate with changes, retire, or keep on another platform. Every Okta object gets one.

**Fallback** — The platform you can return to if something goes wrong. Okta is the fallback until each wave's validation window closes.

**Four steps (Steps 1 to 4)** — The method's sequence. **Step 1, Inventory:** read Okta's full configuration without changing it. **Step 2, Translate:** capture Entra's existing setup and decide an Entra equivalent for every Okta object. **Step 3, Controlled write path:** build the pipeline that is the only way Entra changes. **Step 4, Cutover and decommission:** move users and applications in waves, validate them, then retire Okta. Steps 1 and 2 are read-only; the first change to Entra happens only after Step 3's safeguards exist.

**Gap (attribute gap, translation gap)** — Something an application needs that Entra cannot yet supply, such as a user attribute that does not reach Entra, or an Okta feature with no Entra equivalent. *In this program:* an unresolved gap blocks that application from entering a wave.

**Greenfield / brownfield** — A greenfield system is built from nothing; a brownfield system already has configuration in it. A production Entra tenant is usually brownfield: it already holds Conditional Access policies and applications built by hand over several years.

**Identity as Code** — Managing an identity platform (who can sign in, to what, and under which conditions) by describing its settings in text files, instead of clicking them into an administrative web page. A tool then makes the live system match the files. Think of it as the difference between an architect's blueprint and a builder working from memory: the blueprint can be reviewed, copied, and audited before anything is built. *In this program:* every Entra ID application, group, and sign-in policy is defined in files in the Entra repository (in the lab, the `entra/` folder). *Why it matters to you:* any change to identity becomes a reviewable proposal with a named author and approver, which is what auditors and change management ask for.

**Infrastructure as Code (IaC) / Configuration as Code** — The general practice that Identity as Code belongs to. IaC applies it to servers, networks, and cloud resources; configuration as code applies it to any platform with settings. *In this program:* Terraform is the IaC tool for Okta (read) and Entra ID (write); SailPoint uses its own configuration-as-code format (SP-Config).

**Inventory (Okta discovery)** — A complete, machine-produced list of everything configured in Okta: applications, groups, policies, network zones, and who is assigned to what. It is refreshed every night so the program always works from current facts. *Why it matters to you:* the inventory is what sizes the work, sets wave membership, and tells you how many people each application move will affect.

**Mapping catalog** — The versioned rulebook for translation, kept as YAML files: one file per object family (applications, groups, attributes, policies, authentication methods, exceptions). Each row says what the Okta object becomes, how faithful the translation is, which wave it belongs to, and who owns it.

**Migration factory** — The repeatable machinery that moves applications and users in batches: the inventory, the mapping catalog, the translator, the pipeline, the wave plan, and the runbooks. Called a factory because, once built, each further wave goes through the same steps with little new design work. *In this program:* the factory is proven in non-production Okta and Entra tenants before it touches production.

**Operate (steady state)** — Life after the migration. The same repository and pipeline keep governing every Entra change; drift is checked nightly. The migration leaves behind an operating model, not just a finished project.

**Portal (administrative console)** — The vendor's web page where administrators change settings by hand, such as the Okta Admin Console or the Microsoft Entra admin center. *In this program:* portal changes are allowed only as a documented emergency, and must be copied back into the files within one business day.

**Risk score** — A number per application combining **blast radius** (how many people are assigned), business criticality, technical complexity, and vendor readiness. It decides wave order.

**Rollback** — Returning an application to Okta if validation fails. Because the Okta assignment is still in place during the window, rollback is fast: re-enable the Okta path or revert the Entra change.

**Snapshot** — One night's copy of the inventory. Comparing tonight's snapshot with last night's shows exactly what changed in Okta during the day.

**Source platform / target platform** — The system being left (source: Okta) and the system being moved to (target: Microsoft Entra ID).

**Translation** — Deciding and writing the Entra equivalent of each Okta object: an Okta application becomes an Entra enterprise application, an Okta network zone becomes a named location, and so on. Some translations are exact, some approximate, some manual; each is recorded.

**Translator** — A script that reads the inventory and the mapping catalog and writes draft Entra definitions for engineers to review. It never changes Entra itself; its output is a proposal.

**Validation window** — The waiting period after a cutover during which the application is watched before Okta is touched. Defaults are 30, 14, and 7 days for criticality tiers 1, 2, and 3. *Why it matters to you:* the Okta side is removed only after the window closes with clean results and the application owner signs off.

**Wave** — A batch of users and applications moved together. Waves are grouped by business unit and ordered from lower to higher risk. **Wave 0** is the pilot: IT and IAM staff plus one small business pilot group.

**Wave plan / `waves.yaml`** — The file that lists which applications and user groups are in which wave, in what order. It is generated from the inventory and risk scores, then adjusted by reviewed change with a reason for every move. Business sponsors sign off on it.

**Workstream A, B, C** — The three parallel tracks inside Step 2. **A:** the authentication cutover (moving Microsoft 365 sign-in off Okta). **B:** the brownfield import of the existing Entra configuration. **C:** translating each Okta object into an Entra definition.

---

## Okta concepts

**Application integration (app)** — An application's connection to the IdP: the settings that let people sign in to it through Okta, and which users are allowed. A large enterprise estate can hold hundreds of SAML apps, a few hundred OIDC or OAuth apps, and dozens of SCIM-provisioned apps, plus legacy types.

**Assertion and claims (attributes)** — The assertion is the signed message; claims or attributes are the facts inside it, such as email address, employee ID, department, or group membership. *Why it matters to you:* if an application expects a claim that Entra does not send, sign-in fails, which is why attribute gaps block wave entry.

**Assignment** — The link that grants a user or a group access to a specific Okta application. Removing the assignment is how access ends. *In this program:* Okta assignments are removed only after the Entra side is validated, in a separate change.

**Authorization server** — An Okta component that issues OAuth access tokens and defines scopes (permissions) for APIs (application programming interfaces). Translates to Entra app registrations with exposed API scopes.

**Group and group rule** — A group is a named set of users. A group rule adds people to a group automatically from their attributes, such as department. In a hybrid organization most groups are synced from on-premises Active Directory, so they already exist in Entra and are matched rather than recreated.

**Identity Engine (OIE) / Classic Engine** — Okta's two generations of its sign-in engine. Identity Engine (OIE) is the newer one and organizes sign-in rules as "authentication policies"; Classic uses older "sign-on policies." *In this program:* **Identity Engine only.** The method, inventory and translation are built for OIE; a Classic org must upgrade to OIE before migration starts. Check with the org's `/.well-known/okta-organization` page (`"pipeline": "idx"` means OIE). The lab org is Identity Engine. See docs/okta-identity-engine-decision.md.

**Identity Provider (IdP)** — The system that checks who a person is and vouches for them to applications. Okta is the IdP today; Entra ID will be. An application that trusts an IdP never sees the password; it receives a signed statement that the person is authenticated.

**Network zone** — A named list of IP (Internet Protocol) addresses, such as office networks, used in Okta policies to treat a location as trusted or blocked. It becomes an Entra **named location**.

**OIDC (OpenID Connect) and OAuth 2.0** — Newer standards for sign-in (OIDC) and for granting an application limited access to data on a user's behalf (OAuth 2.0). Common in modern web and mobile applications.

**OIN (Okta Integration Network)** — Okta's catalog of pre-built application integrations. Entra has an equivalent, the application gallery.

**Okta** — The cloud identity service an organization uses to sign people in to applications and, through federation, to Microsoft 365. It is the **source platform** being retired.

**Okta API (application programming interface)** — The machine interface programs use to read and change Okta, instead of a person using the web console. The inventory reads Okta only through the API, with read-only permission. **Rate limit** is the cap on how many API requests Okta accepts per minute; the inventory slows itself down to stay under it.

**Okta org** — One customer's private instance of Okta, with its own web address, users, applications, and settings. An enterprise usually has a production org and a non-production org.

**Okta service app (API service application)** — A non-human identity registered in Okta so an automated job can call the API. It proves itself with a private key rather than a password. *In this program:* the inventory app reads only; the cutover app can change app assignments only, and is switched off between waves.

**Policies (global session, authentication, password, authenticator enrollment)** — Okta Identity Engine's rules for how long a session lasts, what proof of identity each application requires, password rules, and which authenticators (sign-in methods) users must register. Each is translated into Entra's equivalent. Classic orgs used "sign-on" and "MFA enrollment" policies built on factors; this program does not use them.

**Private key JWT (JSON Web Token)** — A way for a service app to prove its identity by signing a short-lived token with a private key it holds, instead of sending a password or a long-lived API token. **SSWS API token** is Okta's older static token type, which the production design does not use (the lab used one to seed the org; see the permission register).

**Profile schema** — The list of attributes Okta stores for each user (name, department, cost center, and custom fields). Needed to find attribute gaps.

**Read-only Administrator** — An Okta administrator role that can view everything and change nothing. Assigned to the inventory service app.

**SAML (Security Assertion Markup Language)** — An older, widely used standard by which an IdP sends an application a signed message (an **assertion**) saying who the user is. Most enterprise web applications use SAML.

**SCIM (System for Cross-domain Identity Management)** — A standard for automatically creating, updating, and removing user accounts inside an application. *In this program:* apps that Okta provisions today move to SailPoint for provisioning, not to Entra.

**Scopes (Okta)** — The specific permissions granted to a service app, such as `okta.apps.read`. Read scopes allow looking, never changing.

**Single sign-on (SSO)** — Signing in once and reaching many applications without signing in again. Both Okta and Entra ID provide SSO.

**SWA (Secure Web Authentication)** — Okta's password-vaulting method for applications that support neither SAML nor OIDC: Okta stores the user's password and fills it in. These apps need a different treatment in Entra and are often candidates for modernization or retirement.

---

## Microsoft Entra ID concepts

**Active Directory (AD)** — Microsoft's on-premises directory, the authoritative store of user accounts and groups in many enterprises. It is not replaced by this migration.

**Admin consent** — A Global Administrator's one-time approval that grants an app the Graph permissions it requested. *In this program:* given once, from the break-glass account, for each pipeline identity.

**App registration** — Entra's definition of an application's identity: its ID, how it proves itself, and what permissions it requests. Used both for applications users sign in to and for non-human identities such as pipeline accounts.

**Authentication methods policy** — The tenant-wide Entra setting that turns individual sign-in methods on or off (Microsoft Authenticator, SMS, voice call, Temporary Access Pass). *In this program:* methods match Okta's at cutover ("parity"); retiring SMS and voice is a dated later phase owned by the CISO (Chief Information Security Officer).

**Authentication strength** — A CA setting naming which sign-in methods are acceptable, such as "phishing-resistant" (security keys, Windows Hello for Business).

**Break-glass (emergency access) account** — A tightly controlled cloud-only Global Administrator account, excluded from every CA policy, used only if normal admin sign-in fails, for example after a bad policy locks everyone out. *In this program:* two per tenant in production (one in the lab), excluded by code and by an automated rule that rejects any change removing the exclusion.

**CA policy naming (descriptive names)** — The program names each policy so its purpose is readable: `<TENANT>-CA<NN> - <Apps> - <Control> - <Persona> - <Conditions>`, for example `PROD-CA10 - Admin portals - Require phishing-resistant MFA and compliant device - P-PRIV-LOCAL - Any location`. The name is generated from the same settings as the policy, so they cannot disagree. The lab uses the `LAB-` prefix.

**Claims mapping policy / custom claims policy** — Two Entra mechanisms for controlling which user attributes are sent to an application in its sign-in token. Which one the program uses is decided by testing in the lab.

**Conditional Access (CA)** — Entra's rule engine that decides, at every sign-in, whether to allow access and under what conditions: for example, require multi-factor authentication from outside the office, require a compliant device for administrators, or block old sign-in methods. Each rule is a **CA policy**. Most enterprises already have many hand-built CA policies.

**Domain conversion** — The one-time change that switches the Microsoft 365 domain from federated (Okta authenticates) to managed (Entra authenticates) for everyone remaining. It is done near the end, after Staged Rollout has moved most users, under a Change Advisory Board (CAB) approved change with executive sign-off. After it, the Okta "Office 365" application is retired. *Why it matters to you:* it is the single highest-impact change in the program, and it gets its own runbook, communications, and rollback plan.

**Drift (Entra)** — Any difference between the files and the live tenant, usually caused by a portal change. See **Drift** in the Terraform section.

**Enterprise application** — Entra's record of an application that users sign in to, including who is assigned and how single sign-on works. The Entra equivalent of an Okta app integration.

**Federation / federated domain** — An arrangement where Entra hands a domain's sign-ins to an outside IdP. In an Okta-federated organization, when someone signs in to Outlook or Teams, Entra sends them to Okta to authenticate.

**Gallery application** — A pre-built Entra template for a known software product, the equivalent of the Okta Integration Network.

**Global Administrator** — The most powerful Entra role; it can change anything in the tenant. Held by as few people as possible.

**Hybrid identity** — An arrangement where user accounts are mastered in on-premises Active Directory (AD) and copied to the cloud. When users are created in AD and synced to both Okta and Entra, the accounts already exist in Entra.

**Hybrid join (Microsoft Entra hybrid join)** — Windows computers that are joined to on-premises AD and also registered in Entra, so Entra can recognize them as company devices in sign-in rules.

**Intune** — Microsoft's device management service. Its device compliance status can be used as a CA condition, for example "only compliant laptops may reach admin portals."

**Log Analytics** — An Azure service that stores and queries large volumes of logs; a candidate source for sign-in analysis.

**Managed domain / cloud authentication** — The opposite of federated: Entra checks the password and multi-factor authentication itself. This is the end state for the organization's domain.

**MFA (multi-factor authentication)** — Requiring two or more kinds of proof at sign-in: something you know (password), have (phone, security key), or are (fingerprint). **Phishing-resistant MFA** uses methods a fake website cannot capture, such as FIDO2 security keys or Windows Hello for Business.

**MFA registration gate** — The rule that a group's users must have registered Microsoft MFA before that group moves to cloud authentication, so nobody is locked out on cutover day.

**Microsoft Entra Connect** — The Microsoft software that copies users, groups, and password hashes from on-premises AD to Entra ID on a schedule (by default about every 30 minutes; some organizations run longer cycles). *Why it matters to you:* a new hire or a group change takes up to one cycle to appear in Entra.

**Microsoft Entra ID** — Microsoft's cloud identity service, formerly called Azure Active Directory (Azure AD). It already signs people in to Microsoft 365 behind the scenes and is the **target platform** for this migration.

**Microsoft Entra ID P1 / P2 / ID Governance** — License tiers. CA needs P1; risk-based policies and PIM need P2; some Tenant Governance features need ID Governance. The lab uses a P2 trial.

**Microsoft Graph and Graph permissions** — Graph is Microsoft's single API for reading and changing Entra and Microsoft 365. Graph permissions are what an app is allowed to do through it, such as `Policy.Read.All` (read policies) or `Policy.ReadWrite.ConditionalAccess` (change CA policies).

**Named location** — A CA setting listing trusted or blocked networks or countries. The Entra equivalent of an Okta network zone.

**Non-production (non-prod) and production (prod) tenants** — Separate tenants used for rehearsal and for real users. Every change is applied to non-prod first. *In this program:* development and test share the non-prod tenant. The lab has one tenant, with `nonprod` and `prod` as GitHub environments.

**Parent and child tenants (governing and governed)** — A multi-tenant model some organizations adopt, using Microsoft's **Tenant Governance** feature. A parent (governing) tenant holds no end users and exists only to administer its children. Authorized administrators in the parent "switch into" a child tenant to manage it, and appear in that child's logs as a technician of the parent. *In this program:* planned for a later paid-tenant build; tenant names are placeholders (`mgmt`, `child-a` to `child-d`, `prod`). The lab only keeps the hook (`tenant_key`, `tenant_id`).

**Password Hash Sync (PHS)** — An Entra Connect feature that copies a protected, irreversible hash of each user's password from AD to Entra so Entra can check passwords itself. Entra never receives the actual password. PHS is a prerequisite for moving sign-in off Okta.

**Persona** — A defined category of user that policies target, with a stable ID: employees (`P-EMP`), contractors (`P-CON`), service accounts (`P-SVC`), workload identities (`P-WLI`), guests (`P-GUEST`), local privileged admins (`P-PRIV-LOCAL`), parent-tenant technicians (`P-PRIV-GOV`), and break-glass accounts (`P-BG`).

**PIM (Privileged Identity Management)** — Makes administrator roles temporary: a person activates a role for a set time, often with approval and a reason, instead of holding it permanently (just-in-time access).

**Rehearsal environment** — The non-prod tenant, seeded from the brownfield import of production so that it behaves like production. Changes are proven here before they reach real users.

**Report-only mode** — A CA policy state in which the policy is evaluated and logged at every sign-in but not enforced. It shows what would have happened. *In this program:* every new CA policy starts in report-only for at least five business days; turning it on is a separate, reviewed change.

**Seamless SSO (single sign-on)** — An Entra feature that signs users on company-joined Windows computers in automatically, without typing a password again, when they are on the corporate network.

**Service principal** — The working instance of an app registration inside a tenant; it is what actually holds permissions and signs in. Every pipeline identity is a service principal.

**Sign-in logs and audit logs** — Entra's records of every sign-in attempt and every configuration change, with who, what, and when. Used for validation, drift attribution, and audit.

**SSPR (self-service password reset)** — Lets users reset their own password after proving identity. *In this program:* Entra SSPR is enabled for pilot users as part of the Entra MVP (minimum viable product).

**Staged Rollout** — An Entra feature that moves selected groups of users to cloud authentication while the domain is still federated to Okta. It lets the program move people group by group, starting with IT staff, instead of all at once. *Why it matters to you:* this is the critical path; every application wave depends on its users already authenticating through Entra.

**TAP (Temporary Access Pass)** — A time-limited passcode an administrator issues so a user can sign in once and register MFA, for example on a new phone. Part of the support process for cutover.

**Tenant** — One organization's private, isolated instance of Entra ID, with its own users, groups, applications, policies, and administrators. Nothing in one tenant is visible to another unless deliberately shared. Comparable to an Okta org. Every tenant has a permanent **initial domain** ending in `.onmicrosoft.com`.

**Windows Hello for Business (WHfB)** — Windows sign-in with a PIN or biometric tied to the device; a phishing-resistant method.

---

## Git and repositories

**Audit log to SIEM (security information and event management)** — GitHub's record of administrative and access events, forwarded to the security team's central monitoring system.

**Branch** — A separate working copy of the files where someone prepares changes without affecting the official version. When the change is approved, the branch is merged back.

**Branch protection** — Repository settings that stop anyone, including administrators, from changing `main` without an approved pull request and passing checks.

**CODEOWNERS** — A file in each repository naming which team must approve changes to which folders. *In this program:* security owns the shared policy rules and the Entra `modules/`; IAM engineering owns tenant, wave, and mapping files; the IGA (Identity Governance and Administration) team owns SailPoint files.

**Commit** — One saved, labeled set of changes in a repository, with its author, date, and a message explaining why. The smallest unit of history.

**Dependabot** — A GitHub feature that proposes updates when a tool or library the repository depends on releases a new version, including security fixes.

**Diff** — The line-by-line display of what was added, removed, or changed between two versions. The nightly Okta snapshot is reviewed as a diff.

**Fork, clone** — A clone is a local copy of a repository on an engineer's computer. A fork is a personal copy on GitHub. Neither changes the official repository.

**Git** — The standard tool for tracking changes to files over time. It records every version of every file, who changed it, when, and the stated reason, and can restore any earlier version. Think of it as track changes and version history for an entire folder, kept forever.

**GitHub / GitHub Enterprise** — A service that hosts Git repositories and adds review, approval, automation, and access control on top. GitHub Enterprise is the paid organizational edition. The lab uses a free GitHub organization with a public repository, because free private repositories have no environment reviewers or environment secrets.

**GitHub App** — A narrowly permissioned automation identity in GitHub. *In this program:* one GitHub App can only read the Okta repository, so the Entra translator can read the inventory without a person's credentials.

**`main` branch** — The official version of the files. In this program, what is in `main` is what the systems should look like. Nobody can change `main` directly.

**Merge** — Accepting an approved pull request into `main`. In this program, merging is what starts the pipeline that applies the change to the non-prod tenant.

**Personal access token (PAT)** — A password-like key tied to an individual's GitHub account. The program avoids them for automation because they carry the person's full access and outlive their role.

**Pull request (PR)** — A formal proposal to merge a branch's changes into `main`. It shows exactly what will change, runs the automated checks, collects review comments, and records who approved it. *Why it matters to you:* the pull request is the change record from the engineering side. It carries the change-record number, the plan of what will change in Entra, the check results, and the approvers. Change managers and auditors can read it directly.

**Repository (repo)** — A folder of files managed by Git, together with its complete change history. *In this program:* the production design has four repositories, one per platform plus a shared one (see the repositories section); the lab uses one. *Why it matters to you:* "the repository" is the official, current definition of the identity system and the evidence trail for every change.

**Review / approval** — A qualified person other than the author examining a pull request and approving it. Required before any merge.

**Tag / release (`@v1`)** — A permanent label on one version of a repository. The shared guardrail repository publishes tagged releases; the other repositories use a specific release, so a change to the shared rules takes effect only when deliberately adopted.

---

## CI/CD, pipelines, and gates

**Blast-radius limit** — A rule that flags or blocks a single change affecting more than a set number of users or objects. An approver can override it with a deliberate label, which is recorded.

**Change gate (`change-gate.yml`)** — The automated step that looks up the change record named in the pull request and stops the pipeline unless it is approved, scheduled for now, for the right configuration item, and requested by someone other than the code's author. After the change, it writes a closure note back to the record. *Why it matters to you:* it connects the engineering approval and the change-management approval mechanically, so a change cannot reach production on a missing, expired, or self-approved ticket. The lab uses GitHub Issues as the change record (see `docs/change-gate-design.md`).

**Check (status check)** — A pass or fail result shown on a pull request, such as "plan succeeded" or "Conftest passed." Branch protection requires all checks to pass before merge.

**CI/CD (continuous integration / continuous delivery)** — The practice of checking every proposed change automatically as soon as it is submitted (CI), then moving approved changes to live systems through an automated, repeatable process (CD). It replaces a person performing the change by hand with a machine performing it the same way every time.

**Conftest** — A command-line tool that runs OPA rules against configuration files, such as a Terraform plan. In the pipeline, Conftest is the step that applies the rules; a failure stops the change.

**Controlled write path** — The program's name for Step 3: the pipeline plus its identities, gates, and rules, which together form the only route by which Entra can be changed.

**Emergency path** — The documented exception for an urgent fix: a portal change made under an emergency change record, then reconciled into the repository by pull request within one business day.

**Environment (GitHub environment)** — A named deployment target in GitHub, such as `nonprod`, `prod`, `okta-read`, `okta-cutover`, `sailpoint-nonprod`, or `sailpoint-prod`. Each environment holds its own approval rules and secrets, and only workflows running in it can obtain its credentials. *Why it matters to you:* the `prod` environment is the lock on production. Its credentials cannot be reached from a pull request or from non-prod.

**Federated credential and subject** — The trust setting on an Entra app registration that names the exact GitHub repository and environment it accepts, called the subject, for example `repo:<org>/<repo>:environment:prod`. A job from any other repository or environment is refused. (Repos using GitHub's immutable subject format add numeric IDs after `@`; see the lab's findings log.)

**Gate** — Any checkpoint a change must pass before it continues: automated (a check that must succeed) or human (an approval).

**GitHub Actions** — GitHub's automation service that runs workflows. It is the engine of the pipeline.

**Job and step** — A workflow is divided into jobs (for example "enumerate" and "generate" in the Okta snapshot), and each job into steps. Separate jobs mean a failure in one does not lose the work of the other.

**OIDC federation (workload identity federation)** — A way for a pipeline to sign in to Azure and Entra without any stored password or key. GitHub issues a short-lived token stating exactly which repository and environment the job is running in; Entra trusts that statement only for the matching identity. The token expires within minutes. *Why it matters to you:* there is no long-lived pipeline password to leak, rotate, or audit.

**OPA (Open Policy Agent)** — A widely used open-source engine for evaluating policy-as-code rules. It answers "is this allowed?" against a set of rules.

**Pipeline** — The automated sequence a change passes through: format and validity checks, a preview of what will change, policy checks, human approval, the change gate, then application to non-prod and later prod. *In this program:* the pipeline is the only thing allowed to change Entra ID. *Why it matters to you:* every production identity change carries the same evidence and passes the same controls, whoever requested it.

**Policy as code** — Automated rules, written as code, that inspect a proposed change and reject it if it breaks a safety rule, before any human reviews it. *In this program:* rules reject any change that removes the break-glass exclusion, enables a CA policy without a report-only period, deletes a legacy object without a recorded decision, contains a secret, exceeds the blast-radius limit, or misnames a CA policy.

**Promotion / promotion PR** — Moving a change already proven in non-prod to prod. The promotion pull request changes only the production lookup file (`lookups/prod.yaml`), so the configuration that reaches production is the same code that was rehearsed.

**Rego** — The language OPA rules are written in. Files end in `.rego`, for example `break-glass-exclusion.rego`.

**Required reviewer** — An environment rule that pauses a workflow until a named person or group approves, and that excludes the person who wrote the change.

**Reusable workflow** — A workflow written once in the shared repository and called by the other repositories, so every repo runs the same checks and the same change gate.

**Runner** — The computer that executes a workflow. GitHub-hosted runners are temporary machines GitHub provides; self-hosted runners sit inside the organization's network. *In this program:* GitHub-hosted is the default unless Okta restricts its API to known IP addresses.

**Scheduled job** — A workflow that runs on a timer rather than on a change, such as the nightly Okta snapshot and the nightly drift check.

**Secret (pipeline secret)** — A credential stored encrypted in a GitHub environment and released only to workflows in that environment. Used only where federation is impossible, such as the Okta private key and the SailPoint API client.

**Trigger** — What starts a workflow: a pull request being opened, a merge to `main`, a schedule ("every night at 02:00"), or a person pressing "run" (manual dispatch).

**Workflow** — One defined automation in GitHub, stored as a YAML file under `.github/workflows/`. For example, `plan.yml` runs on every pull request; `drift.yml` runs every night.

---

## Terraform and configuration files

**Apply (`terraform apply`)** — Carrying out a reviewed plan against the live system. Only the pipeline's `iac-applier` identity may apply, and only from an approved environment. (The lab allows local applies for bootstrap, each one logged.)

**Backend / state backend** — Where state is stored. *In this program:* Azure Storage containers (`tfstate-nonprod`, `tfstate-prod`, and in the design `tfstate-okta`), with versioning, soft delete, locking, and access limited to the pipeline identities.

**`-detailed-exitcode`** — An option that makes a plan report a code: 0 means no differences, 2 means the live system differs from the files. The nightly drift job uses it.

**Drift** — A difference between the files and the live system, usually from someone changing the portal directly. *In this program:* drift is detected nightly and opened as a GitHub issue naming the object and, from the audit log, who changed it. It is never reverted automatically, because the portal change may have been the fix that kept people working. *Why it matters to you:* the open drift count is reported to the steering committee as a measure of discipline.

**Gap layer** — Settings Terraform's main Entra provider cannot manage yet, handled through the `msgraph` provider or small scripts that still pass through the same review and gates. Example: the authentication methods policy.

**`-generate-config-out`** — A Terraform option that writes the HCL for imported objects automatically. Its raw output (`generated.tf`) is then tidied into modules by engineers.

**HCL (HashiCorp Configuration Language)** — The text format Terraform files are written in, ending in `.tf`. Designed to be readable: each block names an object and lists its settings.

**Import / import block** — Telling Terraform to take over management of an object that already exists, without recreating it. Used for the Entra brownfield import and the Okta inventory.

**JSON (JavaScript Object Notation)** — A structured text format machines exchange. The Okta inventory's per-user data and SailPoint's configuration exports are JSON.

**Layer (legacy, platform, waves)** — The program splits Entra configuration into three folders, each managed separately. `legacy/` holds objects imported as they already existed, protected from deletion. `platform/` holds new shared objects such as groups, named locations, authentication strengths, and the baseline CA policies. `waves/` holds the applications moved in each wave.

**Locking** — Prevents two pipeline runs from changing the same state at once.

**Lookup map (`lookups/nonprod.yaml`, `lookups/prod.yaml`)** — Files that translate friendly names to each environment's real object IDs (Entra assigns different IDs in each tenant). Code refers to names; the lookup supplies the ID. Promotion changes only the prod lookup.

**Microsoft365DSC (Desired State Configuration)** — An open-source Microsoft tool that exports Microsoft 365 and Entra settings. *In this program:* read-only, used for snapshots and as a second drift signal for objects Terraform does not manage.

**Module** — A reusable Terraform building block with standard inputs, used many times. For example, the `ca-policy` module builds every CA policy the same way, generates its descriptive name, and always adds the break-glass exclusion. Security owns the modules.

**Normalize / normalization** — Cleaning generated files into consistent modules: removing noise, using lookups instead of hard-coded IDs. The time per application is a key sizing measure.

**Plan (`terraform plan`)** — Terraform's preview of exactly what it would create, change, or delete, without touching anything. *Why it matters to you:* the plan is the change's specification. Reviewers, policy rules, and the CAB judge the plan, not a description of intent.

**`prevent_destroy`** — A Terraform setting that makes any plan to delete the object fail. Applied to every object in `legacy/`.

**Provider** — A plug-in that teaches Terraform how to talk to one platform. The `okta` provider reads Okta; the `azuread` provider manages Entra ID; the `azurerm` provider manages Azure resources such as storage; the `msgraph` provider reaches Entra settings the others do not cover.

**Reconcile** — Resolving drift: either write the portal change into the files (codify it) or change the system back through the pipeline.

**Resource** — One managed object in a Terraform file, such as one CA policy, one group, or one enterprise application.

**State (Terraform state)** — Terraform's record of which real objects it manages and their last known settings, so it can tell what changed. It is sensitive and stored securely, never in Git.

**State key** — A separate state file per layer (for example `entra/legacy/terraform.tfstate`, `entra/platform/terraform.tfstate`, `entra/waves/wave-00/terraform.tfstate`), so a mistake in one layer cannot affect another.

**`tenants.yaml`** — In the future multi-tenant layout, the single file listing every tenant, its role, and its personas. Adding a tenant is a new row.

**Terraform** — HashiCorp's tool for Infrastructure as Code. You describe what should exist in files; Terraform compares that with what actually exists and makes the changes needed to match. *In this program:* Terraform reads Okta and is the only writer to Entra ID. The free Community Edition is used.

**Version pinning** — Fixing the exact version of Terraform, providers, and tools so the pipeline behaves the same until a deliberate upgrade.

**YAML (YAML Ain't Markup Language)** — A simple, indentation-based text format for structured data, used for lists and settings people edit. *In this program:* the mapping catalog, the wave plan (`waves.yaml`), the per-environment lookup files, the tenant map (`tenants.yaml`), and the GitHub workflows are YAML.

---

## Pipeline identities and access

**Accepted risk** — A known risk leadership has chosen to accept, written down with an owner and a trigger for revisiting it.

**Authentication (AuthN), identity, and authorization (AuthZ)** — The three layers of any access decision. **Authentication** proves who or what is signing in. **Identity** is which account does the work. **Authorization** is what that account is allowed to do.

**Blast radius (access)** — How much damage a given identity could cause if misused. The program designs every identity to keep this small. (The same phrase is also used for how many users a single change affects.)

**`iac-cutover-apps`** (lab: `iac-okta-cutover`) — The Okta service app used during cutover to remove, or for rollback re-add, Okta application assignments. Its only permission is `okta.apps.manage`. It is disabled between waves and lives in the gated `okta-cutover` environment, which requires a reviewer and the change gate.

**`iac-inventory-ro`** (lab: `iac-okta-reader`) — The Okta service app the nightly snapshot uses. Read-only scopes plus the Read-only Administrator role. It cannot change Okta. It lives in the `okta-read` GitHub environment.

**`iac-reader`, `iac-planner`, `iac-applier` (the three pipeline identities)** — Every Entra environment has three separate app registrations, each signing in through OIDC federation with no stored secret:

| Identity | What it can do | Where it runs | What it cannot do |
|---|---|---|---|
| `iac-applier` | Change applications, groups, and CA policies (`Application.ReadWrite.All`, `Group.ReadWrite.All`, `Policy.ReadWrite.ConditionalAccess`) and write its own state | Only the `nonprod` or `prod` GitHub environment, after approvals | Be used from a pull request, a branch, another repository, or another environment |
| `iac-planner` | The same read access as `iac-reader`, used to produce a plan for review | Every pull request | Change anything; it is reachable from a pull request, so it is deliberately read-only |
| `iac-reader` | Read Entra configuration (`Directory.Read.All`, `Policy.Read.All`) and read Terraform state | Nightly drift check and Microsoft365DSC snapshot | Change anything |

In the multi-tenant build, each tenant gets its own three, so a credential for one tenant cannot reach another. (In the lab, `iac-reader` also writes the Okta inventory state; see the permission register.)

**Just-in-time (JIT) access** — Access granted only when needed and for a limited time, as with PIM. The opposite of standing access.

**Least privilege** — Granting each identity the minimum access needed for its task and nothing more: read instead of write, one folder instead of a whole drive, temporary instead of permanent. *Why it matters to you:* it limits what a mistake, a compromised credential, or a misbehaving automation can do.

**Non-human identity (service identity, workload identity)** — An account used by software rather than a person. Each automated job has its own, with only the permissions that job needs, so its actions are attributable and its access can be removed without affecting anyone else.

**RBAC (role-based access control)** — Granting access through named roles rather than to individuals one permission at a time.

**Rotation** — Replacing a credential on a schedule so a leaked copy stops working.

**SailPoint API client** — The credential the SailPoint workflow uses to export and import configuration, one per environment, stored only in that environment.

**Separation of duties** — No single identity or person can both propose and approve, or both plan and apply. The three-identity design and the requester-is-not-author rule enforce it.

**`sp-iac-ai-drafter` (proposed)** — From the AI-assisted operating model: a fourth identity for a language model that can read the inventory and propose pull requests but holds no tenant credential and cannot merge.

**Static credential** — A long-lived secret such as a password, API token, or private key file. The program avoids them; where unavoidable (the Okta private key), it is stored in one environment, rotated on a calendar, and recorded as an accepted risk.

**Storage Blob Data Reader / Contributor** — Azure roles for reading, or reading and writing, files in a storage container. Readers get Reader; only the applier gets Contributor on its own state container.

---

## Repositories, folders, and workflow files

The production design uses four repositories, split by platform so each repository's credentials can reach only its own platform. Each serves both non-prod and prod. The file names below are the proposed design and are confirmed in the Step 3 design record.

| Repository | Purpose | Owner |
|---|---|---|
| `identity-as-code-entra` | The only code that changes Entra ID: modules, legacy, platform, waves, mapping catalog, lookups | IAM engineering (modules reviewed by security) |
| `identity-as-code-okta` | Reads Okta nightly; runs the gated assignment removal at cutover | IAM engineering |
| `identity-as-code-sailpoint` | SailPoint configuration for the SCIM applications leaving Okta provisioning | IGA (Identity Governance and Administration) team |
| `identity-as-code-shared` | The guardrails every other repository uses: policy rules, reusable workflows, the change gate, design records and runbooks | Security |

**This repo (lab)** — A single-repository proof of concept on free-tier accounts, used to prove the method before a real build. Originally named `identity-as-code-lab`, now `okta-to-entra-migration-factory`. Not a client deliverable.

### Folders you will see

- `docs/` — Design records, runbooks, the findings log, inventory counts.
- `.github/workflows/` — The automation definitions (YAML) for that repository.
- `inventory/` (Okta repo; lab: `okta-inventory/`) — Terraform that reads Okta: import blocks, generated HCL, tidied modules.
- `legacy/`, `platform/`, `waves/` (lab: under `entra/`) — The three Entra layers (see Terraform section).
- `lookups/` — Per-environment ID files.
- `mapping/` — The mapping catalog (`catalog/*.yaml`) and the translator.
- `modules/` (Entra repo) — Reusable building blocks: `ca-policy`, `enterprise-app-saml`, `app-registration`, `group`, `named-location`, `break-glass`, `pipeline-identities`.
- `platform/gap-layer/` — Settings managed through the `msgraph` provider.
- `policy/` — The OPA rules in Rego, with tests (`tests/`).
- `scripts/` — Small programs: Okta enumeration, counts, cutover, SailPoint export and import.
- `sources/`, `schemas/`, `provisioning-policies/` (SailPoint repo) — SailPoint configuration per application.
- `tools/wave-generator` — Builds `waves.yaml` from inventory and catalog data.

### Supporting files

- `CODEOWNERS` — Who must approve which folders.
- `drift-log.md` — History of drift found and how each was reconciled.
- `.gitignore` — A list of file types Git must never store, such as private keys, state files, and user data exports.
- `inventory-counts.md` — Aggregate Okta counts (no personal data) kept in Git for trend tracking, on branch `inventory-counts` (the bot cannot push to protected `main`).
- **Pull request template** — The form every pull request starts from, including the change-record number field.
- `README.md` — The front page of a repository explaining its purpose.

### Workflow files

- `apply.yml` — Runs on merge: applies to non-prod immediately; applies to prod only in the `prod` environment after the change gate and a reviewer who is not the author.
- `change-gate.yml` — Shared. Verifies the change record and writes the closure note.
- `drift.yml` — Nightly plan-only comparison of prod against the files; any difference opens a GitHub issue.
- `dsc-snapshot.yml` — Nightly read-only Microsoft365DSC export of settings Terraform does not manage.
- `okta-cutover.yml` — Run by hand per wave. Removes, or for rollback re-adds, the Okta assignments listed in `waves.yaml`, after a reviewer and the change gate approve.
- `okta-snapshot.yml` (lab: `snapshot.yml`) — Nightly (weekly in full). Reads Okta through the API, stores per-user data in restricted Azure storage, compares configuration with the HCL, and reports what changed in Okta.
- `plan.yml` — Runs on every Entra pull request: format and validity checks, a Terraform plan per layer, policy rules, and the plan posted to the pull request for reviewers.
- `release.yml` — Shared. Publishes a new tagged version of the guardrails after security review.
- `sailpoint-sync.yml` — Exports SailPoint configuration, compares it with Git, and imports approved changes; prod passes the change gate.
- `terraform-plan.yml`, `terraform-apply.yml`, `conftest.yml` — Shared building blocks the Entra workflows call.

---

## SailPoint, provisioning, and authoritative sources

**Authoritative source** — The system of record that decides whether a person or account exists. Typical examples: an HR (human resources) system such as Workday for employees, a vendor management system for contractors, an ITSM tool for service accounts, and a privileged access tool for administrator accounts.

**Connector** — The adapter SailPoint uses to talk to a particular application. Its credentials are never exported to Git; they are injected at import time from the environment.

**CyberArk** — A common privileged access management (PAM) platform, which controls administrator credentials.

**Fieldglass / VMS (vendor management system)** — A system that tracks contractors and their engagement dates.

**ForgeRock** — Another identity provider some organizations run for legacy and internal applications alongside Okta. Its future is decided separately and is outside this method's scope unless added.

**IGA (Identity Governance and Administration)** — The discipline and tools for deciding who should have access, granting it through approved processes, and reviewing it periodically (access certifications).

**Mock server (Prism)** — In the free-tier lab only: a stand-in for SailPoint built from SailPoint's published API specifications, used to prove the pipeline's shape because SailPoint offers no free tenant. It does not prove SailPoint's real behavior. Deferred in run 1.

**Provisioning / deprovisioning** — Creating, updating, and removing a person's accounts in applications automatically as they join, change roles, or leave. Separate from sign-in: sign-in decides whether you can get in; provisioning decides whether you have an account at all.

**Provisioning policy** — SailPoint's rules for how a new account is built in a target application: which attributes, from where, in what format.

**SailPoint Identity Security Cloud (ISC)** — SailPoint's cloud IGA platform. *In this program:* SailPoint becomes the standard for provisioning; the applications Okta provisions today move to SailPoint, not to Entra's own provisioning.

**Source (SailPoint)** — A system SailPoint reads identities from or writes accounts to, such as an HR system, Active Directory, or a SCIM application.

**SP-Config** — SailPoint's own export and import format for its configuration (JSON files). *In this program:* SailPoint configuration is managed as code with SP-Config and the same pipeline gates, not with Terraform.

**Workday** — A widely used HR system; hiring and termination there drive employee accounts.

---

## Governance, change management, and roles

**Application owner** — The person accountable for an application. Sets its criticality tier, confirms its required attributes, tests it at cutover, and signs off before Okta is removed.

**Business sponsor** — The leader for each business unit who approves that unit's wave plan and timing and acknowledges large-wave advisories.

**CAB (Change Advisory Board)** — The group that reviews and approves significant changes. *In this program:* each wave's change record, the domain conversion, and the Okta decommission go to CAB. CAB members who wrote the code under review are excluded from approving it.

**Change record (change request, change ticket)** — The ITSM record that authorizes a change: what, why, when (the change window), which configuration item, who requested it, and who approved it. *In this program:* every production change's pull request must name an approved, in-window change record, and the pipeline checks it automatically.

**Change window** — The approved date and time range for a change. The gate refuses to apply outside it.

**Closure work note** — The note the pipeline writes back to the change record after applying: the commit, the plan summary, and the result. It is evidence that the change implemented matches the change approved.

**Configuration item (CI)** — The ITSM record for the system being changed, such as the production Entra tenant. The change gate checks that the change record names the right one. (Not to be confused with CI meaning continuous integration.)

**Criticality tier** — An application's business importance (tier 1 highest). It sets the validation window: 30, 14, or 7 days.

**Design record** — The engineering document for each step (Steps 1 to 4) recording decisions, architecture, and open items.

**Error-rate delta** — The difference between sign-in failure rates on Entra and on the Okta baseline for the same application. A sustained increase of more than 2 percentage points triggers escalation.

**Go/no-go** — The decision point just before cutover, using a checklist of gates the pipeline can verify plus sponsor approval.

**Large-wave advisory** — A warning, not a block, raised when a wave exceeds 5,000 assignments or 10 applications. The sponsor acknowledges it.

**MVP (minimum viable product)** — The smallest working version delivered first; here, the Entra configuration needed for the pilot.

**Normal, standard, and emergency change** — ITSM change types. Normal changes go through full CAB review; standard changes are pre-approved repeatable changes; emergency changes are urgent and reviewed after the fact. The pipeline accepts an emergency change only with a reconcile obligation.

**Open item / working assumption** — A fact or decision not yet confirmed, and the assumption used until it is.

**Pilot group** — A small group of business users who move first after IT staff, chosen because they use a representative set of applications.

**Planning worksheet** — The list of every design decision with its options, the working assumption, and what it drives, completed with the organization.

**Program executive owner** — The executive who owns the decommission milestone, approves domain conversion and decommission, and resolves conflicts between business units.

**Requester is not author** — The rule that the person requesting or approving a change cannot be the person who wrote it. The pipeline enforces it for both the GitHub approval and the change record. *Why it matters to you:* it keeps the gate from becoming a formality.

**Residual-usage hold** — Okta is removed for an application only after 7 days with no successful non-admin Okta sign-ins to it.

**Rollback trigger** — A predefined condition that requires returning an application to Okta, such as a synthetic test failing for 30 minutes unresolved.

**Runbook** — Step-by-step operating instructions for a procedure: a wave, a rollback, an emergency change, the domain conversion. The lab's is `docs/migration-runbook.md`.

**Scorecard** — The per-wave summary for steering: what moved, validation results, tickets, rollbacks, and open issues.

**ServiceNow** — A widely used IT service management (ITSM) platform for tickets, incidents, and change records. In the lab, GitHub Issues stand in for it.

**SOW (Statement of Work)** — The contract document defining scope, deliverables, and timeline.

**Steering committee** — Meets monthly to review wave scorecards, open drift, open decisions, and risks, and approves wave plan changes that affect more than one unit.

**Synthetic test** — An automated test that signs in to an application as a test user on a schedule (every 15 minutes for 48 hours after cutover, then hourly) to catch failures before users report them.

**TOM (target operating model)** — How identity will be run after the migration: who owns what, which processes, which tools.

**Wave lifecycle (T-15 to T+30)** — The standard calendar around each cutover day (T-0): prepare at T-15 days, rehearse at T-10, communicate at T-5, cut over at T-0, validate for the window, remove Okta in a separate change, and hold a retrospective at T+30.

---

## FAQ

**Can an administrator still change things in the portal?** Technically yes, by policy only in an emergency under an emergency change. The nightly drift check finds any portal change the next morning, names who made it, and opens an issue to reconcile it within one business day.

**How do I know a production change was approved?** Every production change has a pull request that links its change record, shows the plan of exactly what changed, lists the reviewers, and records the check results. The pipeline will not apply without an approved, in-window change record whose requester is not the code's author, and it writes a closure note back to the record.

**Is this the multi-tenant design or the single-tenant one?** The current build uses one non-prod and one prod target (in the lab, one tenant with two GitHub environments). The parent and child tenant model is designed for a follow-on paid-tenant build and uses placeholder tenant names.

**What do auditors get?** The repository is the documented baseline; the pull request is the change control record; the pipeline identities are the access restriction; drift reports are the continuous check. Evidence is produced as a by-product of the work rather than assembled before each audit.

**What does my team need to do?** Application owners: confirm the application's criticality tier and required attributes during catalog curation, test at cutover, and sign off. Service desk: use the wave's runbook and tag tickets to the wave. Change management: review wave change records and the pull request evidence. Business sponsors: approve the unit's wave timing.

**What happens if a cutover goes wrong?** The Okta configuration for that application is still in place throughout its validation window. Rollback re-enables the Okta path or reverts the Entra change through the pipeline, and the fix comes back later as a new pull request.

**What is usually undecided at the start?** The Okta engine type, whether Okta restricts API access by network, Password Hash Sync and Seamless SSO status, the approach to existing CA policies, MFA method hardening timing, and the policy-as-code owner. Track these in the planning worksheet with working assumptions.

**When is Okta actually gone?** Each application's Okta assignment is removed after its validation window and 7 days of zero Okta use. Okta as a whole is decommissioned after the last wave and the domain conversion, on a fixed date owned by the program executive owner.

**Who approves what?** Engineers write changes; CODEOWNERS (IAM engineering or security) review them; automated rules reject unsafe ones; CAB approves the change record; a reviewer who is not the author releases it to production; business sponsors approve wave plans; application owners sign off validation; the executive owner approves domain conversion and decommission.

**Why are there four repositories instead of one?** Each repository can reach only its own platform. A compromised or mistaken Entra pipeline cannot touch Okta or SailPoint, and each team approves only its own code. (The lab uses one repository for simplicity.)

**Why does this take longer at the start than clicking it in?** The first version of anything as code takes longer, because the design is written down and checked before it is built. The time is recovered on every later wave, every environment, every audit, and every rebuild.

**Will users notice the migration?** Mostly at two moments: when their group moves to Entra sign-in (they may be asked to register Microsoft MFA first), and when each application they use cuts over (the sign-in page looks different). Communications go out at T-5 for each wave. The domain conversion near the end should be invisible to users already moved by Staged Rollout.

---

## Acronym quick reference

| Acronym | Full name | Section |
|---|---|---|
| AD | Active Directory | [Entra ID](#microsoft-entra-id-concepts) |
| API | Application programming interface | [Okta](#okta-concepts) |
| AuthN / AuthZ | Authentication / authorization | [Identities and access](#pipeline-identities-and-access) |
| CA | Conditional Access | [Entra ID](#microsoft-entra-id-concepts) |
| CAB | Change Advisory Board | [Governance](#governance-change-management-and-roles) |
| CI | Continuous integration, or configuration item (ITSM) | [CI/CD](#cicd-pipelines-and-gates); [Governance](#governance-change-management-and-roles) |
| CI/CD | Continuous integration / continuous delivery | [CI/CD](#cicd-pipelines-and-gates) |
| CISO | Chief Information Security Officer | [Entra ID](#microsoft-entra-id-concepts) |
| DSC | Desired State Configuration (Microsoft365DSC) | [Terraform](#terraform-and-configuration-files) |
| HCL | HashiCorp Configuration Language | [Terraform](#terraform-and-configuration-files) |
| HR | Human resources | [SailPoint](#sailpoint-provisioning-and-authoritative-sources) |
| IaC | Infrastructure as Code | [Program](#program-and-method-concepts) |
| IAM | Identity and Access Management | [Program](#program-and-method-concepts) |
| IdP | Identity provider | [Okta](#okta-concepts) |
| IGA | Identity Governance and Administration | [SailPoint](#sailpoint-provisioning-and-authoritative-sources) |
| IP | Internet Protocol (address) | [Okta](#okta-concepts) |
| ISC | Identity Security Cloud (SailPoint) | [SailPoint](#sailpoint-provisioning-and-authoritative-sources) |
| ITSM | IT service management | [Governance](#governance-change-management-and-roles) |
| JIT | Just-in-time (access) | [Identities and access](#pipeline-identities-and-access) |
| JSON | JavaScript Object Notation | [Terraform](#terraform-and-configuration-files) |
| JWT | JSON Web Token | [Okta](#okta-concepts) |
| MFA | Multi-factor authentication | [Entra ID](#microsoft-entra-id-concepts) |
| MVP | Minimum viable product | [Governance](#governance-change-management-and-roles) |
| OIDC | OpenID Connect | [Okta](#okta-concepts); [CI/CD](#cicd-pipelines-and-gates) |
| OIE | Okta Identity Engine | [Okta](#okta-concepts) |
| OIN | Okta Integration Network | [Okta](#okta-concepts) |
| OPA | Open Policy Agent | [CI/CD](#cicd-pipelines-and-gates) |
| P1 / P2 | Microsoft Entra ID license tiers | [Entra ID](#microsoft-entra-id-concepts) |
| PAM | Privileged access management | [SailPoint](#sailpoint-provisioning-and-authoritative-sources) |
| PAT | Personal access token | [Git](#git-and-repositories) |
| PHS | Password Hash Sync | [Entra ID](#microsoft-entra-id-concepts) |
| PII | Personally identifiable information | Note below this table |
| PIM | Privileged Identity Management | [Entra ID](#microsoft-entra-id-concepts) |
| PR | Pull request | [Git](#git-and-repositories) |
| RBAC | Role-based access control | [Identities and access](#pipeline-identities-and-access) |
| SAML | Security Assertion Markup Language | [Okta](#okta-concepts) |
| SCIM | System for Cross-domain Identity Management | [Okta](#okta-concepts); [SailPoint](#sailpoint-provisioning-and-authoritative-sources) |
| SIEM | Security information and event management | [Git](#git-and-repositories) |
| SOW | Statement of Work | [Governance](#governance-change-management-and-roles) |
| SP-Config | SailPoint configuration export and import format | [SailPoint](#sailpoint-provisioning-and-authoritative-sources) |
| SSO | Single sign-on | [Okta](#okta-concepts); [Entra ID](#microsoft-entra-id-concepts) |
| SSPR | Self-service password reset | [Entra ID](#microsoft-entra-id-concepts) |
| SSWS | Okta's legacy static API token type | [Okta](#okta-concepts) |
| SWA | Secure Web Authentication | [Okta](#okta-concepts) |
| TAP | Temporary Access Pass | [Entra ID](#microsoft-entra-id-concepts) |
| TOM | Target operating model | [Governance](#governance-change-management-and-roles) |
| VMS | Vendor management system | [SailPoint](#sailpoint-provisioning-and-authoritative-sources) |
| WHfB | Windows Hello for Business | [Entra ID](#microsoft-entra-id-concepts) |
| YAML | YAML Ain't Markup Language | [Terraform](#terraform-and-configuration-files) |

**PII (personally identifiable information)** means data that identifies a person, such as names, emails, and assignment lists. In this program it is stored only in restricted Azure storage, never in Git.

---

## Lab names vs. design names

The glossary describes the production design. The lab (this repo) proves the same ideas with free accounts and simpler stand-ins.

| Production design | Lab (this repo) |
|---|---|
| Four repositories (`identity-as-code-entra`, `-okta`, `-sailpoint`, `-shared`) | One repository: `iac-migration-lab/okta-to-entra-migration-factory` |
| `iac-inventory-ro` (Okta read) | `iac-okta-reader` |
| `iac-cutover-apps` (Okta cutover) | `iac-okta-cutover` |
| ServiceNow change record | GitHub Issue labeled `change` (`docs/change-gate-design.md`) |
| `okta-snapshot.yml` | `.github/workflows/snapshot.yml` |
| Separate non-prod and prod tenants | One lab tenant (`lamigrationlaboutlook.onmicrosoft.com`); `nonprod` and `prod` are GitHub environments |
| `PROD-CA<NN>` names | `LAB-CA<NN>` names |
| Two break-glass accounts per tenant | One: `bg-admin-01`, group `bg-ca-exclusion` |
| Least-privilege grants from day one | Broad grants allowed, each logged with a production verdict in `docs/permission-register.md` |
| SailPoint ISC tenant | Prism mock (deferred in run 1) |
