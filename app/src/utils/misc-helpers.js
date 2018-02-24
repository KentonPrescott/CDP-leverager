let API_ORACLE;
if (process.env.NODE_ENV === "production") {
  API_ORACLE = "/api/oracle/current";
} else {
  API_ORACLE = "https://api-cdp-stats-oracle-current.now.sh/";
}

export const isMobile = () => {
  const mobileRegex = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i;

  return mobileRegex.test(navigator.userAgent) || window.innerWidth < 450;
};

export const fetchOracleCurrent = () => {
  return fetch(API_ORACLE)
    .then(response => response.json())
    .then(priceObj => {
      return priceObj.result;
    });
};

export const twoDecimalFloat = num => {
  return parseFloat(num.toFixed(2));
};
