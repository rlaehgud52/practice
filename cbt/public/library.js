'use strict';

const stateKey = 'cbt-2025-3-state';
const byId = id => document.getElementById(id);

function readState() {
  try {
    const state = JSON.parse(localStorage.getItem(stateKey) || '{"answers":{},"flags":{}}');
    return state && typeof state.answers === 'object' ? state : { answers: {}, flags: {} };
  } catch {
    return { answers: {}, flags: {} };
  }
}

function createExamCard(bank, state) {
  const answered = bank.questions.filter(question => state.answers[question.id] != null).length;
  const imageCount = bank.questions.filter(question => question.images?.length).length;
  const progress = bank.questions.length ? Math.round(answered / bank.questions.length * 100) : 0;
  const card = document.createElement('article');
  card.className = 'exam-card';

  const top = document.createElement('div');
  top.className = 'card-top';
  const number = document.createElement('span');
  number.className = 'card-number';
  number.textContent = '01';
  const badge = document.createElement('span');
  badge.className = 'available-badge';
  badge.textContent = '학습 가능';
  top.append(number, badge);

  const category = document.createElement('p');
  category.className = 'card-category';
  category.textContent = '기존 CBT';
  const title = document.createElement('h3');
  title.textContent = bank.title;
  const details = document.createElement('p');
  details.className = 'card-details';
  details.textContent = `객관식 ${bank.questions.length}문항 · 사진자료 ${imageCount}개`;

  const progressHeading = document.createElement('div');
  progressHeading.className = 'progress-heading';
  const progressLabel = document.createElement('span');
  progressLabel.textContent = '진행률';
  const progressCount = document.createElement('strong');
  progressCount.textContent = `${answered} / ${bank.questions.length}`;
  progressHeading.append(progressLabel, progressCount);

  const progressTrack = document.createElement('div');
  progressTrack.className = 'card-progress';
  progressTrack.setAttribute('role', 'progressbar');
  progressTrack.setAttribute('aria-label', `${bank.title} 풀이 진행률`);
  progressTrack.setAttribute('aria-valuemin', '0');
  progressTrack.setAttribute('aria-valuemax', String(bank.questions.length));
  progressTrack.setAttribute('aria-valuenow', String(answered));
  const progressFill = document.createElement('span');
  progressFill.style.width = `${progress}%`;
  progressTrack.append(progressFill);

  const action = document.createElement('a');
  action.className = 'card-action';
  action.href = '/exam.html';
  action.textContent = answered ? '이어서 풀기' : '문제 풀기';
  action.setAttribute('aria-label', `${bank.title} ${action.textContent}`);

  card.append(top, category, title, details, progressHeading, progressTrack, action);
  return { card, answered };
}

async function loadLibrary() {
  try {
    const response = await fetch('/questions.json', { cache: 'no-store' });
    if (!response.ok) throw new Error('문제 데이터를 불러오지 못했습니다.');
    const bank = await response.json();
    if (!bank || typeof bank.title !== 'string' || !Array.isArray(bank.questions)) {
      throw new Error('문제 데이터 형식을 확인할 수 없습니다.');
    }

    const state = readState();
    const { card, answered } = createExamCard(bank, state);
    const list = byId('examList');
    list.replaceChildren(card);
    byId('bankCount').textContent = '1';
    byId('questionCount').textContent = String(bank.questions.length);
    byId('answeredCount').textContent = String(answered);
  } catch (error) {
    byId('examList').replaceChildren();
    byId('loadError').hidden = false;
    byId('loadError').textContent = error.message;
    byId('bankCount').textContent = '0';
    byId('questionCount').textContent = '0';
    byId('answeredCount').textContent = '0';
  }
}

loadLibrary();
