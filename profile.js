angular.module('timing', [])
    .directive('focusInput', function ($timeout) {
        return {
            link: function (scope, element, attrs) {
                element.bind('click', function () {
                    $timeout(function () {
                        element.parent().find('input')[0].focus();
                    });
                });
            }
        };
    })
    .controller('MainCtrl', [
        '$scope', '$http', '$window',
        function ($scope, $http, $window) {
            $scope.profile = {};
            $scope.return = {};
            $scope.eci = "ckzj0rsyv000jasu04ah59p3d";

            var bURL = 'http://192.168.86.182:3000/sky/cloud/ckyv0ojp5002ib0u05x6c5vuz/sensor_profile/sensor_profile';
            $scope.getProfile = function () {
                return $http.get(bURL).success(function (data) {
                    angular.copy(data, $scope.profile);
                });
            };

            var iURL = 'http://192.168.86.182:3000/sky/event/ckyv0ojp5002ib0u05x6c5vuz/test/sensor/profile_updated';
            $scope.updateProfile = function () {
                console.log($scope);
                var pURL = iURL + "?location=" + $scope.location + "&name=" + $scope.name + "&threshold=" + $scope.threshold + "&number=" + $scope.number;
                return $http.get(pURL).success(function (data) {
                    $scope.getProfile();
                    angular.copy(data, $scope.return)
                });
            };

            $scope.getProfile();

            console.log($scope);

        }
    ]);