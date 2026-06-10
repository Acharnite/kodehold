Tool ordering rules:

1. READ BEFORE WRITE — Always read files before editing them. Use Glob+Grep to find files, Read to understand them, then Edit/Write.

2. PREFER SPECIALIZED OVER GENERIC — Use the most specific tool for the job:
   - Find files: Glob (not bash find)
   - Search content: Grep (not bash grep)
   - Read: Read tool (not bash cat)
   - Edit sections: Edit (not sed)
   - Write new files: Write (not bash heredoc)

3. BATCH INDEPENDENT READS — Read multiple files in parallel. Never read one file at a time.

4. AVOID BASH FOR TEXT — Do NOT use bash for grep/sed/cat/head/tail/find operations. Use dedicated tools.

5. SIZE MATTERS — For files over 500 lines, read in sections (offset+limit). Read the first 50 lines first to understand structure.

6. VERIFY CHANGES — After an edit, read the modified region to confirm the change is correct.

7. COMMIT LAST — Only commit when explicitly asked. Before commit: check git status, diff, and recent log.

8. NEVER git clean -fd without explicit user confirmation.

9. NEVER force-push, use -i interactive, or amend without explicit request.

Note: Rules 8-9 are universal safety rules, not just KodeHold policies.