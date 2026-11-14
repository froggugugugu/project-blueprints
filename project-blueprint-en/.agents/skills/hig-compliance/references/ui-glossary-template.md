# UI Glossary Template

Template used by `hig-compliance` Phase 1 (glossary establishment) to generate `docs/ui-glossary.md`.

```markdown
# UI Glossary

## Button Label Standards

| Action | Standard Label | Incorrect Examples | HIG Basis |
| ------ | -------------- | ------------------ | --------- |
| Create | Create | New, Add, Make new | Buttons: concise verbs indicating the action |
| Save | Save | Store, Keep, OK | Buttons: use specific verbs |
| Delete | Delete | Remove, Erase, Discard | Buttons: clearly indicate destructive actions |
| Cancel | Cancel | Dismiss, Never mind, Go back | Buttons: "Cancel" as the standard |
| Confirm | [specific verb] | OK, Yes, Confirm | Buttons: prefer specific verbs over "OK" |

## Page Title Standards

| Pattern | Format | Example |
| ------- | ------ | ------- |
| List screen | [Noun] List or [Noun]s | Users |
| Detail screen | [Noun] Details or [Noun Name] | User Details |
| Create screen | Create [Noun] | Create User |
| Edit screen | Edit [Noun] | Edit User |
| Settings screen | Settings or [Category] Settings | Notification Settings |

## Icon Usage Standards

| Action | Standard Icon | Required/Recommended |
| ------ | ------------- | -------------------- |
| Add | Plus / PlusCircle | Recommended |
| Delete | Trash2 | Required |
| Edit | Pencil / Edit | Recommended |
| Search | Search | Required |
| Settings | Settings / Gear | Required |
| Back | ArrowLeft / ChevronLeft | Required |
| Close | X | Required |
| Menu | Menu / MoreHorizontal / MoreVertical | Required |
| Filter | Filter / SlidersHorizontal | Recommended |
| Sort | ArrowUpDown | Recommended |

## Notification Message Standards

| Type | Format | Example |
| ---- | ------ | ------- |
| Success | "[Noun] [past tense verb] successfully" | User created successfully |
| Error | "Failed to [verb] [noun]" | Failed to create user |
| Confirmation | "[Verb] this [noun]?" | Delete this user? |
| Warning | "[Impact description]. [Verb]?" | This action cannot be undone. Delete? |
```
