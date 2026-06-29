# Freelance Projects in Twenty CRM

Guide for representing freelance projects in Twenty CRM at `crm.home.lan`.

## Two Approaches

### Option 1: Use the built-in Opportunities Object (Simplest)

Opportunities already have a pipeline (Kanban) view. Configure stages for freelance workflow:

1. Go to **Settings → Data Model → Opportunities → Stage field**
2. Rename/add stages to match your freelance flow:
   - `Lead` → `Proposal Sent` → `Negotiation` → `Accepted` → `In Progress` → `Delivered` → `Invoiced` → `Paid`
3. Link each opportunity to a **Company** (client) and **Person** (contact)
4. Add custom fields: hourly rate, estimated hours, deadline, tech stack, etc.

### Option 2: Create a Custom "Project" Object (More Structured)

1. Go to **Settings → Data Model → Create Object**
2. Name it "Project" with fields:

| Field       | Type                  | Purpose                      |
|-------------|-----------------------|------------------------------|
| Status      | SELECT                | Lead / Quoted / Active / Delivered / Invoiced / Closed |
| Rate        | NUMBER                | Hourly/project rate          |
| Budget      | NUMBER                | Total project value          |
| Start Date  | DATE                  | Project start                |
| Deadline    | DATE                  | Delivery date                |
| Client      | RELATION → Company    | Link to client               |
| Contact     | RELATION → Person     | Main contact                 |
| Opportunity | RELATION → Opportunity| Link to the originating deal |
| Tech Stack  | MULTI-SELECT          | Technologies involved        |
| Notes       | RICH TEXT             | Project description          |

## Recommended Setup

Use both together: Opportunities for the sales pipeline (lead → won), then a linked Project object for delivery tracking (active → delivered → invoiced). This mirrors the natural freelance lifecycle.

The pipeline view gives you a Kanban board for either object, and relation fields connect everything together.
