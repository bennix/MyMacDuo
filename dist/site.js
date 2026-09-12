const languageButtons = document.querySelectorAll('[data-language]');
const translatedElements = document.querySelectorAll('[data-zh][data-en]');
const translatedImages = document.querySelectorAll('[data-alt-zh][data-alt-en]');
const description = document.querySelector('meta[name="description"]');

const pageCopy = {
  zh: {
    lang: 'zh-CN',
    title: 'Mac Duo — 让合盖更有层次',
    description: 'Mac Duo 为 MacBook 合盖与打开添加实时景深动画和可自定义双音效。'
  },
  en: {
    lang: 'en',
    title: 'Mac Duo — A responsive MacBook lid experience',
    description: 'Mac Duo adds a live depth animation and customizable close and open sounds to your MacBook.'
  }
};

function applyLanguage(language) {
  const selected = language === 'en' ? 'en' : 'zh';
  document.documentElement.lang = pageCopy[selected].lang;
  document.title = pageCopy[selected].title;
  description.setAttribute('content', pageCopy[selected].description);

  translatedElements.forEach((element) => {
    element.textContent = element.dataset[selected];
  });
  translatedImages.forEach((image) => {
    image.alt = image.dataset[`alt${selected === 'zh' ? 'Zh' : 'En'}`];
  });
  languageButtons.forEach((button) => {
    button.setAttribute('aria-pressed', String(button.dataset.language === selected));
  });
  localStorage.setItem('mac-duo-language', selected);
}

languageButtons.forEach((button) => {
  button.addEventListener('click', () => applyLanguage(button.dataset.language));
});

const savedLanguage = localStorage.getItem('mac-duo-language');
const initialLanguage = savedLanguage || (navigator.language.toLowerCase().startsWith('zh') ? 'zh' : 'en');
applyLanguage(initialLanguage);
