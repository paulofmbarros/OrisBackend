module.exports = {
    extends: ['@commitlint/config-conventional'],
    rules: {
        // You can add custom types here (e.g., 'chore', 'refactor', 'perf')
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
        'subject-case': [2, 'always', 'sentence-case'], // Optional: enforces sentence case
    },
};