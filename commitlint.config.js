module.exports = {
    extends: ['@commitlint/config-conventional'],
    parserPreset: {
        parserOpts: {
            // Defines what a "issue" looks like.
            // Adjust 'OR-' to match your actual Jira project key (e.g. 'PROJ-')
            issuePrefixes: ['OR-']
        }
    },
    rules: {
        // 1. Enforce standard types
        'type-enum': [
            2,
            'always',
            [
                'feat',     // New feature
                'fix',      // Bug fix
                'docs',     // Documentation changes
                'style',    // Formatting, missing semi-colons, etc; no code change
                'refactor', // Refactoring production code
                'test',     // Adding missing tests
                'chore',    // Updating grunt tasks etc; no production code change
                'perf',     // Performance improvements
                'ci',       // CI related changes
                'revert'    // Reverting a previous commit
            ],
        ],
        // 2. Enforce Sentence case (e.g. "Add login", not "add login")
        'subject-case': [2, 'always', 'sentence-case'],

        // 3. FORCE TICKET REFERENCE
        // This rule says: "It is an error (2) to never have a reference."
        'references-empty': [2, 'never'],
    },
};