'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { mapLegacyQuestionBank } = require('../scripts/migrate-legacy-questions');

const bank = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'data', 'questions.json'), 'utf8'));
const migration = fs.readFileSync(path.join(__dirname, '..', 'supabase', 'migrations', '202611120001_foundation.sql'), 'utf8');

test('maps all legacy questions as private and preserves answer numbering and nulls', () => {
  const mapped = mapLegacyQuestionBank(bank, 'user-1');
  assert.equal(mapped.length, 35);
  assert.ok(mapped.every(item => item.question.visibility === 'private'));
  assert.ok(mapped.every(item => item.key.answer === null));
  assert.equal(mapped[0].question.legacy_id, bank.questions[0].id);
  assert.equal(mapped[0].question.legacy_number, bank.questions[0].number);
  assert.deepEqual(mapped[0].choices.map(choice => choice.position), [1, 2, 3, 4, 5]);
  assert.deepEqual(mapped[0].question.legacy_metadata.images, bank.questions[0].images);
});

test('keeps a known one-based answer and explanation', () => {
  const fixture = { title: 'fixture', questions: [{
    id: 'q1', stem: 'Stem', choices: ['A', 'B'], answer: 2, explanation: 'Because', images: []
  }] };
  const [mapped] = mapLegacyQuestionBank(fixture, 'user-1');
  assert.equal(mapped.key.answer, 2);
  assert.equal(mapped.key.explanation, 'Because');
});

test('maps mixed multiple-choice and short-answer exam items without changing unanswered values', () => {
  const fixture = {
    id: 'psychiatry-24', title: '정신의학 24 · 과정시험',
    source_metadata: { source: 'user-export' },
    questions: [
      { id: 'mcq-1', type: 'objective', prompt: 'Question?', options: ['A', 'B'], answer: null },
      { id: 'sa-1', type: 'subjective', question: 'Written answer?', expected_answer: '예시 답', accepted_answers: ['답 하나', '답 둘'] }
    ]
  };
  const mapped = mapLegacyQuestionBank(fixture, 'user-1');
  assert.deepEqual(mapped.map(item => item.question.question_type), ['single_choice', 'short_answer']);
  assert.equal(mapped[0].key.answer, null);
  assert.equal(mapped[1].key.answer, null);
  assert.equal(mapped[1].key.expected_answer, '예시 답');
  assert.deepEqual(mapped[1].key.accepted_answers, ['답 하나', '답 둘']);
  assert.equal(mapped.every(item => item.question.visibility === 'private'), true);
});

test('rejects invalid one-based answers and duplicate legacy ids', () => {
  const invalidAnswer = { title: 'fixture', questions: [{
    id: 'q1', stem: 'Stem', choices: ['A', 'B'], answer: 0
  }] };
  assert.throws(() => mapLegacyQuestionBank(invalidAnswer, 'user-1'), /one-based answer/);
  const duplicateIds = { title: 'fixture', questions: [
    { id: 'q1', stem: 'A', choices: ['A', 'B'] },
    { id: 'q1', stem: 'B', choices: ['A', 'B'] }
  ] };
  assert.throws(() => mapLegacyQuestionBank(duplicateIds, 'user-1'), /duplicate id/);
});

test('migration defines the requested tables with RLS enabled', () => {
  const tables = [
    'profiles', 'subjects', 'exam_banks', 'lectures', 'lecture_files', 'pdf_pages', 'extracted_blocks',
    'questions', 'question_choices', 'question_sources', 'attempts', 'attempt_answers',
    'question_memos', 'flashcards', 'review_logs'
  ];
  for (const table of tables) {
    assert.match(migration, new RegExp(`create table public\\.${table}\\s*\\(`, 'i'), `${table} table missing`);
    assert.match(migration, new RegExp(`alter table public\\.${table} enable row level security`, 'i'), `${table} RLS missing`);
  }
  assert.match(migration, /create table public\.question_keys/i);
  assert.match(migration, /create policy .* on public\.exam_banks/is);
  assert.match(migration, /create policy .* on storage\.objects/is);
  assert.match(migration, /values \('lecture-files', 'lecture-files', false\)/i);
});
