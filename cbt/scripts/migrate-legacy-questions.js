#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

function mapLegacyQuestionBank(bank, ownerId) {
  if (!bank || typeof bank.title !== 'string' || !Array.isArray(bank.questions)) {
    throw new Error('Expected a legacy bank with title and questions[].');
  }
  if (typeof ownerId !== 'string' || !ownerId.trim()) {
    throw new Error('An authenticated user ID is required for private import.');
  }

  const ids = new Set();
  return bank.questions.map((question, index) => {
    const position = index + 1;
    if (!question || typeof question.id !== 'string' || !question.id.trim() || ids.has(question.id)) {
      throw new Error(`Question ${position} has a missing or duplicate id.`);
    }
    ids.add(question.id);
    if (typeof question.stem !== 'string' || !question.stem.trim()
      || !Array.isArray(question.choices) || question.choices.length < 2
      || question.choices.some(choice => typeof choice !== 'string' || !choice.trim())) {
      throw new Error(`Question ${position} has invalid stem or choices.`);
    }
    if (question.answer != null
      && (!Number.isInteger(question.answer) || question.answer < 1 || question.answer > question.choices.length)) {
      throw new Error(`Question ${position} has an invalid one-based answer.`);
    }
    if (question.images != null
      && (!Array.isArray(question.images) || question.images.some(image => typeof image !== 'string'))) {
      throw new Error(`Question ${position} has invalid images.`);
    }

    return {
      question: {
        owner_id: ownerId,
        legacy_id: question.id,
        legacy_number: Number.isInteger(question.number) ? question.number : position,
        subject_id: null,
        lecture_id: null,
        stem: question.stem,
        visibility: 'private',
        legacy_metadata: {
          images: question.images || [],
          legacy_title: bank.title,
          legacy_format_version: 1
        }
      },
      choices: question.choices.map((choice, choiceIndex) => ({
        position: choiceIndex + 1,
        choice_text: choice
      })),
      key: {
        answer: question.answer ?? null,
        explanation: typeof question.explanation === 'string' ? question.explanation : ''
      }
    };
  });
}

async function requestJson(url, headers, options = {}) {
  const response = await fetch(url, { ...options, headers });
  const text = await response.text();
  if (!response.ok) throw new Error(`Supabase request failed (${response.status}): ${text}`);
  return text ? JSON.parse(text) : null;
}

async function importBank(bank, records, env) {
  const baseUrl = env.SUPABASE_URL.replace(/\/$/, '');
  const headers = {
    apikey: env.SUPABASE_ANON_KEY,
    Authorization: `Bearer ${env.SUPABASE_USER_ACCESS_TOKEN}`,
    'Content-Type': 'application/json'
  };
  const user = await requestJson(`${baseUrl}/auth/v1/user`, headers);
  const ownerId = user.id;
  const subjectRows = await requestJson(
    `${baseUrl}/rest/v1/subjects?on_conflict=owner_id,title`,
    { ...headers, Prefer: 'resolution=merge-duplicates,return=representation' },
    { method: 'POST', body: JSON.stringify([{
      owner_id: ownerId,
      title: bank.title,
      description: 'Imported from the legacy CBT question bank.',
      visibility: 'private'
    }]) }
  );
  const subjectId = subjectRows[0].id;

  for (const record of records) {
    const questionRows = await requestJson(
      `${baseUrl}/rest/v1/questions?on_conflict=owner_id,legacy_id`,
      { ...headers, Prefer: 'resolution=merge-duplicates,return=representation' },
      { method: 'POST', body: JSON.stringify([{ ...record.question, owner_id: ownerId, subject_id: subjectId }]) }
    );
    const questionId = questionRows[0].id;
    await requestJson(
      `${baseUrl}/rest/v1/question_keys?on_conflict=question_id`,
      { ...headers, Prefer: 'resolution=merge-duplicates,return=minimal' },
      { method: 'POST', body: JSON.stringify([{ question_id: questionId, ...record.key }]) }
    );
    const choices = record.choices.map(choice => ({ ...choice, question_id: questionId }));
    await requestJson(
      `${baseUrl}/rest/v1/question_choices?on_conflict=question_id,position`,
      { ...headers, Prefer: 'resolution=merge-duplicates,return=minimal' },
      { method: 'POST', body: JSON.stringify(choices) }
    );
  }
  return { ownerId, subjectId, questionCount: records.length };
}

async function main(argv = process.argv.slice(2), env = process.env) {
  const apply = argv.includes('--apply');
  const fileArg = argv.find((arg, index) => argv[index - 1] === '--file');
  const filePath = path.resolve(fileArg || path.join(__dirname, '..', 'data', 'questions.json'));
  const bank = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const records = mapLegacyQuestionBank(bank, apply ? 'pending-authenticated-user' : 'dry-run-owner');
  const nullAnswers = records.filter(record => record.key.answer === null).length;

  if (!apply) {
    console.log(JSON.stringify({ mode: 'dry-run', title: bank.title, questions: records.length, nullAnswers }, null, 2));
    return;
  }
  for (const name of ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_USER_ACCESS_TOKEN']) {
    if (!env[name]) throw new Error(`--apply requires ${name} in the environment.`);
  }
  const result = await importBank(bank, records, env);
  console.log(JSON.stringify({ mode: 'applied', ...result, nullAnswers }, null, 2));
}

if (require.main === module) {
  main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { mapLegacyQuestionBank, main };
