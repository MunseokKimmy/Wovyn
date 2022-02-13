angular.module('timing', [])
.directive('focusInput', function($timeout) {
  return {
    link: function(scope, element, attrs) {
      element.bind('click', function() {
        $timeout(function() {
          element.parent().find('input')[0].focus();
        });
      });
    }
  };
})
.controller('MainCtrl', [
  '$scope','$http','$window',
  function($scope,$http,$window){
    $scope.temperatures = [];
    $scope.violations = [];
    $scope.inrange = [];
    $scope.eci = "ckzj0rsyv000jasu04ah59p3d";

    var bURL = 'http://192.168.86.182:3000/sky/cloud/ckyv0ojp5002ib0u05x6c5vuz/temperature_store/temperatures';
    $scope.getTemperatures = function() {
      return $http.get(bURL).success(function(data){
        angular.copy(data, $scope.temperatures);
      });
    };

    var iURL = 'http://192.168.86.182:3000/sky/cloud/ckyv0ojp5002ib0u05x6c5vuz/temperature_store/threshold_violations';
    $scope.getViolations = function() {
      return $http.get(iURL).success(function(data){
        angular.copy(data, $scope.violations)
      });
    };

    var gURL = 'http://192.168.86.182:3000/sky/cloud/ckyv0ojp5002ib0u05x6c5vuz/temperature_store/inrange_temperatures';
    $scope.getInrange = function() {
      return $http.get(gURL).success(function(data){
        angular.copy(data, $scope.inrange);
      });
    };
    $scope.getTemperatures();
    $scope.getViolations();
    $scope.getInrange();
    console.log($scope);

    $scope.timeDiff = function(timing) {
      var bgn_sec = Math.round(Date.parse(timing.time_out)/1000);
      var end_sec = Math.round(Date.parse(timing.time_in)/1000);
      var sec_num = end_sec - bgn_sec;
      var hours   = Math.floor(sec_num / 3600);
      var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
      var seconds = sec_num - (hours * 3600) - (minutes * 60);
  
      if (hours   < 10) {hours   = "0"+hours;}
      if (minutes < 10) {minutes = "0"+minutes;}
      if (seconds < 10) {seconds = "0"+seconds;}
      return hours+':'+minutes+':'+seconds;
    }
  }
]);