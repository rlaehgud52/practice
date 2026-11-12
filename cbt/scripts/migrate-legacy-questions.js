#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

function mapLegacyQuestionBank(bank, ownerId) {
  if (!bank || typeof bank.title !== 'string' || !bank.title.trim() || !Array.isArray(bank.questions)) {
    throw new Error('Expected a bank with title and questions[].');
  }
  if (typeof ownerId !== 'string' || !ownerId.trim()) throw new Error('An authenticated user ID is required for private import.');
  const sourceKey = String(bank.source_key || bank.id || bank.slug || bank.title).trim();
  if (!sourceKey) throw new Error('Bank needs a stable source_key, id, slug, or title.');
  const ids = new Set();
  return bank.questions.map((raw, index) => {
    const position = index + 1;
    if (!raw || typeof raw !== 'object') throw new Error(`Question ${position} is invalid.`);
    const stem = String(raw.stem ?? raw.prompt ?? raw.question ?? '').trim();
    const choicesRaw = raw.choices ?? raw.options ?? [];
    if (!stem || !Array.isArray(choicesRaw)) throw new Error(`Question ${position} has invalid stem or choices.`);
    const choices = choicesRaw.map(choice => typeof choice === 'string' ? choice : String(choice?.text ?? choice?.label ?? choice?.value ?? ''));
    if (choices.some(choice => !choice.trim())) throw new Error(`Question ${position} has an empty choice.`);
    const typeText = String(raw.question_type ?? raw.type ?? '').toLowerCase();
    const subjective = ['short_answer', 'subjective', 'essay', '주관식', '단답형'].includes(typeText) || choices.length === 0;
    if (!subjective && choices.length < 2) throw new Error(`Question ${position} needs at least two choices.`);
    if (subjective && choices.length) throw new Error(`Question ${position} is subjective but has choices.`);
    const id = String(raw.id ?? raw.question_id ?? raw.number ?? position).trim();
    if (!id || ids.has(id)) throw new Error(`Question ${position} has a missing or duplicate id.`);
    ids.add(id);
    const rawAnswer = raw.answer ?? raw.correct_answer ?? raw.answer_index ?? null;
    let answer = null;
    let expectedAnswer = null;
    if (subjective) {
      if (rawAnswer != null) expectedAnswer = String(rawAnswer);
      if (raw.expected_answer != null) expectedAnswer = String(raw.expected_answer);
    } else if (rawAnswer != null) {
      if (Number.isInteger(rawAnswer)) answer = rawAnswer;
      else if (typeof rawAnswer === 'string' && /^\d+$/.test(rawAnswer.trim())) answer = Number(rawAnswer);
      else if (typeof rawAnswer === 'string') {
        const found = choices.findIndex(choice => choice.trim() === rawAnswer.trim());
        if (found >= 0) answer = found + 1;
      }
      if (answer == null || answer < 1 || answer > choices.length) throw new Error(`Question ${position} has an invalid one-based answer.`);
    }
    const accepted = raw.accepted_answers ?? raw.acceptedAnswers ?? [];
    if (!Array.isArray(accepted) || accepted.some(item => typeof item !== 'string')) throw new Error(`Question ${position} has invalid accepted_answers.`);
    const images = raw.images ?? raw.image ?? [];
    if (!(typeof images === 'string' || (Array.isArray(images) && images.every(item => typeof item === 'string')))) throw new Error(`Question ${position} has invalid images.`);
    return {
      question: {
        owner_id: ownerId, exam_bank_id: null, legacy_id: id,
        legacy_number: Number.isInteger(raw.number) ? raw.number : position,
        subject_id: null, lecture_id: null,
        question_type: subjective ? 'short_answer' : 'single_choice', stem, visibility: 'private',
        legacy_metadata: {
          images: Array.isArray(images) ? images : [images],
          source_metadata: raw.source_metadata ?? raw.source ?? null,
          legacy_title: bank.title, legacy_format_version: 2
        }
      },
      choices: choices.map((choice, choiceIndex) => ({ position: choiceIndex + 1, choice_text: choice })),
      key: {
        answer, expected_answer: expectedAnswer, accepted_answers: accepted,
        explanation: typeof raw.explanation === 'string' ? raw.explanation : ''
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
  const headers = { apikey: env.SUPABASE_ANON_KEY, Authorization: `Bearer ${env.SUPABASE_USER_ACCESS_TOKEN}`, 'Content-Type': 'application/json' };
  const user = await requestJson(`${baseUrl}/auth/v1/user`, headers);
  const subjectRows = await requestJson(`${baseUrl}/rest/v1/subjects?on_conflict=owner_id,title`,
    { ...headers, Prefer: 'resolution=merge-duplicates,return=representation' },
    { method: 'POST', body: JSON.stringify([{ owner_id: user.id, title: bank.subject || bank.title, description: 'Imported CBT question bank.', visibility: 'private' }]) });
  const sourceKey = String(bank.source_key || bank.id || bank.slug || bank.title).trim();
  const examRows = await requestJson(`${baseUrl}/rest/v1/exam_banks?on_conflict=owner_id,source_key`,
    { ...headers, Prefer: 'resolution=merge-duplicates,return=representation' },
    { method: 'POST', body: JSON.stringify([{
      owner_id: user.id, subject_id: subjectRows[0].id, source_key: sourceKey,
      title: bank.title, description: typeof bank.description === 'string' ? bank.description : '',
      visibility: 'private', source_metadata: bank.source_metadata && typeof bank.source_metadata === 'object' ? bank.source_metadata : {}
    }]) });
  const examBankId = examRows[0].id;
  for (const record of records) {
    const questionRows = await requestJson(`${baseUrl}/rest/v1/questions?on_conflict=exam_bank_id,legacy_id`,
      { ...headers, Prefer: 'resolution=merge-duplicates,return=representation' },
      { method: 'POST', body: JSON.stringify([{ ...record.question, owner_id: user.id, subject_id: subjectRows[0].id, exam_bank_id: examBankId }]) });
    const questionId = questionRows[0].id;
    await requestJson(`${baseUrl}/rest/v1/question_keys?on_conflict=question_id`,
      { ...headers, Prefer: 'resolution=merge-duplicates,return=minimal' },
      { method: 'POST', body: JSON.stringify([{ question_id: questionId, ...record.key }]) });
    if (record.choices.length) await requestJson(`${baseUrl}/rest/v1/question_choices?on_conflict=question_id,position`,
      { ...headers, Prefer: 'resolution=merge-duplicates,return=minimal' },
      { method: 'POST', body: JSON.stringify(record.choices.map(choice => ({ ...choice, question_id: questionId }))) });
  }
  return { ownerId: user.id, subjectId: subjectRows[0].id, examBankId, questionCount: records.length };
}

async function main(argv = process.argv.slice(2), env = process.env) {
  const apply = argv.includes('--apply');
  const fileArg = argv.find((arg, index) => argv[index - 1] === '--file');
  const filePath = path.resolve(fileArg || path.join(__dirname, '..', 'data', 'questions.json'));
  const bank = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const records = mapLegacyQuestionBank(bank, apply ? 'pending-authenticated-user' : 'dry-run-owner');
  const summary = {
    mode: apply ? 'applied' : 'dry-run', title: bank.title, questions: records.length,
    singleChoice: records.filter(record => record.question.question_type === 'single_choice').length,
    shortAnswer: records.filter(record => record.question.question_type === 'short_answer').length,
    nullAnswers: records.filter(record => record.key.answer === null && record.key.expected_answer === null).length
  };
  if (!apply) { console.log(JSON.stringify(summary, null, 2)); return summary; }
  for (const name of ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_USER_ACCESS_TOKEN']) if (!env[name]) throw new Error(`--apply requires ${name} in the environment.`);
  const result = await importBank(bank, records, env);
  console.log(JSON.stringify({ ...summary, ...result }, null, 2));
  return { ...summary, ...result };
}

if (require.main === module) main().catch(error => { console.error(error.message); process.exitCode = 1; });
module.exports = { mapLegacyQuestionBank, main };
