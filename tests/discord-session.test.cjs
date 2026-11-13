const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const bootstrap = fs.readFileSync(path.join(__dirname, '../LainCord/DiscordSession.js'), 'utf8');

function run(token, origin = 'https://discord.com', mainFrame = true) {
    const writes = [];
    const window = {location: {origin}, localStorage: {setItem: (...args) => writes.push(args)}};
    window.top = mainFrame ? window : {};
    vm.runInNewContext(`${bootstrap}(${JSON.stringify(token)});`, {window});
    return writes;
}

test('credentials are written only to the exact HTTPS Discord origin', () => {
    assert.deepEqual(run('test-token'), [['token', '"test-token"']]);
    for (const origin of ['http://discord.com', 'https://discord.com.evil.test',
                          'https://evil.test', 'https://support.discord.com']) {
        assert.deepEqual(run('test-token', origin), []);
    }
});

test('embedded frames never receive the token', () => {
    assert.deepEqual(run('test-token', 'https://discord.com', false), []);
});

test('empty and non-string credentials do not touch the session', () => {
    for (const token of ['', null, 123, {}]) assert.deepEqual(run(token), []);
});

test('special characters remain data rather than executable script', () => {
    const token = '\"\\\n); throw new Error("injection"); //';
    assert.deepEqual(run(token), [['token', JSON.stringify(token)]]);
});
