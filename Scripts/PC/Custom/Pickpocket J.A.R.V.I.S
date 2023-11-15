// ==UserScript==
// @name         Pickpocket J.A.R.V.I.S.
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  color pick-pocket targets based on difficulty
// @author       Terekhov
// @match        https://www.torn.com/loader.php?sid=crimes*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=torn.com
// @grant        none
// ==/UserScript==
 
(function () {
  'use strict';
  //
  // Based on guide here https://www.torn.com/forums.php#/p=threads&f=61&t=16358739&b=0&a=0
  // Thanks Emforus [2535044]!
  //
  // This script is triggered down at the bottom; see formatCrimesContainerOnce and startListeningToFormatNewCrimes
  //
  const lsKey = 'pickpocketSkillLevel';
 
  // Need to wait for page to initialize, before we know this. Assume 1, until then
  let currentSkillLevel = 1;
 
  function findChildByClassStartingWith(name, parentEle) {
    for (let child of parentEle.children) {
      for (let childClass of child.classList) {
        if (!!childClass && childClass.startsWith(name)) {
          return child;
        }
      }
    }
    return null;
  }
 
  const colors = {
    ideal:         '#40AB24',
    easy:          '#82C370',
    tooEasy:       '#A4D497',
    tooHard:       '#fa8e8e',
    uncategorized: '#DA85FF'
  };
  const ALL_MARK_TYPES = [
    'Businessman',
    'Businesswoman',
    'Classy lady',
    'Cyclist',
    'Drunk man',
    'Drunk woman',
    'Elderly man',
    'Elderly woman',
    'Gang member',
    'Homeless person',
    'Jogger',
    'Junkie',
    'Laborer',
    'Mobster',
    'Police officer',
    'Postal worker',
    'Rich kid',
    'Sex worker',
    'Student',
    'Thug',
    'Young man',
    'Young woman'
  ];
  const MARK_CS_LEVELS_MAP = {
 
    'Drunk man': '100',
    'Drunk woman': '100',
    'Elderly man': '100',
    'Elderly woman': '100',
    'Homeless person': '100',
    'Junkie': '100',
 
    'Classy lady': '150',
    'Laborer': '150',
    'Postal worker': '150',
    'Young man': '150',
    'Young woman': '150',
    'Student': '150',
 
    'Rich kid': '200',
    'Sex worker': '200',
    'Thug': '200',
 
    'Businessman': '250',
    'Businesswoman': '250',
    'Jogger': '250',
    'Gang member': '250',
    'Mobster': '250',
 
    'Cyclist': '300',
 
    'Police officer': '350'
  };
 
  /**
   *
   * @return {
   *    csSemantic: 'tooHard', // Police officer when you're lvl 1
   *    activitySemantic: 'ideal',    // Businesswoman 'on phone'
   *    buildSemantic: 'tooHard'     // Skinny businessman,
   *    finalSemantic: 'tooHard'
   * }
   */
  function setColorsForCrimeTarget(crimeChild) {
    const crimesDivAkaSections = findChildByClassStartingWith('sections', crimeChild);
    const mainSection = findChildByClassStartingWith('mainSection', crimesDivAkaSections);
 
 
    let targetTypeEle = findChildByClassStartingWith('titleAndProps', mainSection).children[0];
    let targetType;
 
    for (let type of ALL_MARK_TYPES) {
      if (targetTypeEle.textContent.startsWith(type)) {
        // Handle mobile view e.g. "Police officer 5m 10s"
        targetType = type;
      }
    }
 
    // e.g. Average 5'0" 158 lbs
    const physicalPropsEle = findChildByClassStartingWith('titleAndProps', mainSection).children[1];
    const physicalProps = physicalPropsEle.textContent;
 
    // Average
    const build = physicalProps.substring(0, physicalProps.indexOf(' '));
 
    // e.g. Begging0s
    const activityEle = findChildByClassStartingWith('activity', mainSection);
    const activity = activityEle.textContent;
 
    // e.g. Begging
    // The ternary handles mobile - in mobile we don't get the status like "Begging" so we can't do optimize there.
    const activityName = activity.match(/^\D+/) ? activity.match(/^\D+/)[0] : '';
 
    // e.g. 0s
    // const activityTime = activity.substring(activityName.length);
 
    //
    // type DifficultySemantic = 'ideal' | 'easy' | 'tooEasy' | 'tooHard' | 'uncategorized'
    // interface Difficulties: { [key]: DifficultySemantic } = {
    //   csSemantic: 'tooHard',       // Police officer when you're lvl 1
    //   activitySemantic: 'ideal',    // Businesswoman 'on phone'
    //   buildSemantic: 'tooHard'     // Skinny businessman
    //   finalSemantic: 'tooHard',    // Based on all the above
    // }
    //
    const difficulties = getDifficulties(targetType, build, activityName);
 
    //
    // Now Set all the colors
    //
    if (difficulties.buildSemantic) {
      physicalPropsEle.style.color = colors[difficulties.buildSemantic];
    }
    if (difficulties.activitySemantic) {
      activityEle.style.color = colors[difficulties.activitySemantic];
    }
    for (let type of ALL_MARK_TYPES) {
      if (targetTypeEle.textContent.startsWith(type)) {
        // Handle mobile view e.g. "Police officer 5m 10s"
        if (targetTypeEle.textContent.indexOf('%)') === -1) {
          targetTypeEle.textContent = targetTypeEle.textContent + ` (${MARK_CS_LEVELS_MAP[type]}%)`;
        }
        targetTypeEle.style.color = colors[difficulties.csSemantic];
      }
    }
 
 
 
    // Set 'Pickpocket' button color
    const divContainingButton = findChildByClassStartingWith('commitButtonSection', crimesDivAkaSections);
    divContainingButton.style.backgroundColor = colors[difficulties.finalSemantic];
  }
 
  let skillCats = ['Safe', 'Moderately Unsafe', 'Unsafe', 'Risky', 'Dangerous', 'Very Dangerous'];
  let skillStarts = [1, 10, 35, 65, 90, 100];
 
  function getMaxSkillIndex() {
    let idx = 0;
    skillStarts.forEach((ele, currentIdx) => {
      if (Math.floor(currentSkillLevel) >= ele) {
        idx = currentIdx;
      }
    });
    return idx;
  }
 
  function getAllSafeSkillCats() {
    let maxIndex = getMaxSkillIndex();
    if (maxIndex >= skillCats.length) {
      return skillCats.slice();
    } else {
      return skillCats.slice(0, maxIndex + 1);
    }
  }
  const markGroups = {
    // CS 1-20
    'Safe': ['Drunk man', 'Drunk woman', 'Homeless person', 'Junkie', 'Elderly man', 'Elderly woman'],
 
    // CS 10-70
    'Moderately Unsafe': ['Laborer', 'Postal worker', 'Young man', 'Young woman', 'Student'],
 
    // CS 35-90
    'Unsafe': ['Classy lady', 'Rich kid', 'Sex worker'],
 
    // CS 65+
    'Risky': ['Thug', 'Jogger', 'Businessman', 'Businesswoman', 'Gang member'],
 
    // CS 90+
    'Dangerous': ['Cyclist'],
 
    // ???
    'Very Dangerous': ['Mobster', 'Police officer'],
  };
 
 
  /**
   * @param mark e.g. 'Rich Kid'
   *
   * @return 'ideal' | 'easy' | 'tooEasy' | 'tooHard' | 'uncategorized'
   */
  function getMarkIdealityBasedOnCS(mark) {
    // type colorSemantic = 'ideal' | 'easy' | 'tooEasy' | 'tooHard' | 'uncategorized'
    let safeSkillCats = getAllSafeSkillCats();
    for (let idx = 0; idx < safeSkillCats.length; idx++) {
      let safeSkillCat = safeSkillCats[idx];
      if (markGroups[safeSkillCat].includes(mark)) {
        if (idx === safeSkillCats.length - 1) {
          return 'ideal';
        } else if (idx === safeSkillCats.length - 2) {
          return 'easy';
        } else {
          return 'tooEasy';
        }
      }
    };
    return 'tooHard';
  }
 
  /**
   *
   * @param markType  Elderly woman
   * @param build     Average
   * @param status    Begging
   *
   * @return {
   *    csSemantic: 'tooHard', // Police officer when you're lvl 1
   *    activitySemantic: 'ideal',    // Businesswoman 'on phone'
   *    buildSemantic: 'tooHard'     // Skinny businessman,
   *    finalSemantic: 'tooHard'
   * }
   */
  function getDifficulties(markType, build, status) {
    // TODO builds and statuses to favor. Too much for now
    const buildsToAvoid = {
      'Businessman': ['Skinny'],
      'Drunk man': ['Muscular'],
      'Gang member': ['Muscular'],
      'Sex worker': ['Muscular'],
      'Student': ['Athletic'],
      'Thug': ['Muscular']
    };
    const statusesToAvoid = {
      'Businessman': ['Walking'],
      'Drunk man': ['Distracted'],
      'Drunk woman': ['Distracted'],
      'Homeless person': ['Loitering'],
      'Junkie': ['Loitering'],
      'Laborer': ['Distracted'],
      'Police officer': ['Walking'],
      'Sex worker': ['Distracted'],
      'Thug': ['Loitering', 'Walking']
    };
    const difficulties = {
      csSemantic: 'uncategorized',
      activitySemantic: undefined,
      buildSemantic: undefined,
      finalSemantic: 'uncategorized'
    }
 
    // type colorSemantic = 'ideal' | 'easy' | 'tooEasy' | 'tooHard' | 'uncategorized'
    difficulties.csSemantic = getMarkIdealityBasedOnCS(markType);
 
    // We use csSemantic as baseline; activity and build can override.
    difficulties.finalSemantic = difficulties.csSemantic;
 
    if (buildsToAvoid[markType] && buildsToAvoid[markType].includes(build)) {
      difficulties.finalSemantic = 'tooHard';
      difficulties.buildSemantic = 'tooHard'
    }
    if (statusesToAvoid[markType] && statusesToAvoid[markType].includes(status)) {
      difficulties.finalSemantic = 'tooHard';
      difficulties.activitySemantic = 'tooHard';
    }
    return difficulties;
  }
 
  function getCrimesContainer() {
    let crimesContainerName = document.querySelectorAll('[class^="crimeOptionGroup"]')[0].classList[0];
    return document.getElementsByClassName(crimesContainerName)[0];
  }
 
  function setSkillLevel() {
    currentSkillLevel = +document.getElementsByClassName('slick-slide')[0].children[0].children[0].children[0].children[2].textContent;
  }
 ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 // The part of the script that starts listening to the page is below
 ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 
  // If we land directly on pickpocket page, these handle it correctly.
  setTimeout(formatCrimesContainerOnce, 650);
  let pageLandingInterval = setInterval(startListeningToFormatNewCrimes, 650);
 
  //
  // GreaseMonkey can't listen for Pickpocket page directly, so we run this on all crimes pages.
  // however if we navigate away from Pickpocket, we stop listening with our observer
  //
 let pagePopInterval;
  window.onpopstate = function(event) {
    setTimeout(formatCrimesContainerOnce, 650);
    pagePopInterval = setInterval(startListeningToFormatNewCrimes, 650);
  }
 
  function formatCrimesContainerOnce() {
    if (!window.location.href.includes("#/pickpocketing")) {
      return;
    }
    setSkillLevel();
 
    for (let node of getCrimesContainer().children) {
      setColorsForCrimeTarget(node);
    }
  }
 
 /**
  * This function clears any attempts to add new listeners to the page.
  * This functions DOES NOT actually add listeners - 
  *   see the Mutation Observers in startListeningToFormatNewCrimes for those listeners
  */
 function clearPickpocketIntervals(reason) {
      if (pageLandingInterval) {
         console.warn('clearing pageLandingInterval: ' + reason);
        clearInterval(pageLandingInterval);
      }
      if (pagePopInterval) {
        console.warn('clearing pagePopInterval: ' + reason);
        clearInterval(pagePopInterval);
      }
 }
 
  let observer;
  let alreadyListening = false;
  function startListeningToFormatNewCrimes() {
    if (!window.location.href.includes("#/pickpocketing")) {
      if (observer) {
        observer.disconnect();
        observer = undefined;
      }
      alreadyListening = false;
      clearPickpocketIntervals('not pickpocketing page');
      return;
    }
    if (alreadyListening) {
      clearPickpocketIntervals('already listening');
      return;
    }
    setSkillLevel();
 
    // Select the node that will be observed for mutations
    const targetNode = getCrimesContainer();
 
    // Options for the observer (which mutations to observe)
    const config = {
      attributes: false,
      childList: true,
      subtree: false
    };
 
    // Callback function to execute when mutations are observed
    const callback = (mutationList, observer) => {
      for (const mutation of mutationList) {
        if (mutation.type === "childList" && mutation.addedNodes.length > 0) {
 
          for (let node of targetNode.children) {
            setColorsForCrimeTarget(node);
          }
        }
      }
    };
 
    // Create an observer instance linked to the callback function
    observer = new MutationObserver(callback);
 
    // Start observing the target node for configured mutations
    observer.observe(targetNode, config);
    alreadyListening = true;
  } 
})();