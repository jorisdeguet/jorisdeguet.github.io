$(document).ready(function () {
    $('a').smoothScroll();
});
// could use http://cpettitt.github.io/project/dagre-d3/latest/demo/interactive-demo.html for graph
var app = angular.module('PreferentialDemo', ['pascalprecht.translate']);
app.config(function ($translateProvider) {
    $translateProvider.useSanitizeValueStrategy('escape');
    $translateProvider.translations('en', {
        LANGUAGE: 'Language'
        , EXAMPLES: 'Examples'
        , DATA: 'Data'
        , VOTES: 'Votes'
        , RACE_TO_50 : 'The race to a majority'
        , RESULT: 'Results'
        , RANKING: 'Ranking',

        BTN_PARSE_VOTES: 'Parse the votes'
        , BTN_COMPUTE_INITIAL: 'Compute initial results'
        , BTN_ELIMINATE_LOSER: 'Eliminate the loser',

        P_PREFERENCES: 'Each person vote by expressing preference.'
        , P_A_OVER_B: 'means the voter prefers A to B.'
        , P_C_EQUAL_D: 'means the voter likes them the same.'
        , P_E_CD_A: 'means E is the first choice, then C and D are the second choice and A would be the worst.'
        , P_123_MEANS: 'means 123 people have expressed the "A and then B" vote.'
        , P_EACH_LINE: 'Each line corresponds to a different preferential vote with the number of people voting it.',

        P_EXTRACT_VOTES: 'We extract the votes from the provided text.',

        P_FIRST_TO_50: 'We are looking for a 50% majority for one of the candidates.\
We will eliminate candidates until we have such a majority.'
        , P_ELIMINATE_THE_LAST: 'We successively eliminate the candidate with the lower current score.'
        , P_DISTRIBUTE_VOTES: 'We redistribute the votes of this candidate to the next candidate that is still running for every ballot. This will increase scores for some candidates. This is the equivalent of an election where the eliminated candidates do not exist.'
    });
    $translateProvider.translations('fr', {
        LANGUAGE: 'Langue'
        , EXAMPLES: 'Exemples'
        , DATA: 'Données'
        , VOTES: 'Votes'
        , RACE_TO_50 : 'La course à la majorité'
        , RESULT: 'Résultats'
        , RANKING: 'Classement',

        BTN_PARSE_VOTES: 'Extraire les votes'
        , BTN_COMPUTE_INITIAL: 'Calculer les résultats initiaux'
        , BTN_ELIMINATE_LOSER: 'Éliminer le dernier',

        P_PREFERENCES: 'Chaque électeur exprime ses préférences.'
        , P_A_OVER_B: 'signifie que l\'électeur préfère A à B.'
        , P_C_EQUAL_D: 'signifie que l\'électeur les situe au même niveau.'
        , P_E_CD_A: 'signifie que l\'électeur préfère E puis C et D indifféremment et enfin A.'
        , P_123_MEANS: 'signifie que 123 personnes ont exprimé le vote A puis B.'
        , P_EACH_LINE: 'Chaque ligne correspond à un ordre de préférence et au nombre d\'électeurs l\'ayant choisi.',

        P_EXTRACT_VOTES: 'On extrait les votes à partir du texte fourni.',

        P_FIRST_TO_50: 'On veut trouver une majorité de plus de la moitié des votes pour un candidat.\
On va chercher à éliminer un candidat à la fois, jusqu\'à obtenir un majoritaire.'
        , P_ELIMINATE_THE_LAST: 'On va éliminer le candidat qui a actuellement le score le plus bas.'
        , P_DISTRIBUTE_VOTES: 'On va ensuite redistribuer les votes pour ce candidat au prochain candidat encore dans la course pour chaque bulletin. Cela fait monter les scores des autres. Cela correspond au résultat si le candidat éliminé n\'avait pas participé.'
    });
    //$translateProvider.determinePreferredLanguage();
    $translateProvider.preferredLanguage('fr');
});
app.controller('PrefController', function ($window, $scope, $http, $filter, $timeout, $anchorScroll, $translate, $location) {
    console.log("locale " + $location.search().l);
    console.log($location.search());

    $scope.colors = ['rgb(255,80,5)', 'rgb(43,206,72)', 'rgb(194,0,136)'
                , 'rgb(0,117,220)', 'rgb(200,200,0)'
                 , 'rgb(225,138,157)', 'rgb(0,153,143)'
                 , 'rgb(240,163,255)'
                 , 'rgb(255,164,5)', 'rgb(255,0,16)'
                , ];

    $scope.votes = "5:A>C>B>E>D\n5:A>D>E>C>B\n8:B>E>D>A>C\n3:C>A>B>E>D\n" +
        "7:C>A>E>B>D\n2:C>B>A>D>E\n7:D>C>E>B>A\n8:E>B>A>D>C";
    $scope.memphis = function () {
        $scope.votes =
            "42:Memphis>Nashville>Chattanooga>Knoxville\n" +
            "26:Nashville>Chattanooga>Knoxville>Memphis\n" +
            "15:Chattanooga>Knoxville>Nashville>Memphis\n" +
            "17:Knoxville>Chattanooga>Nashville>Memphis\n";
        $scope.init();
        $.smoothScroll({
            scrollTarget: '#data'
        });
    }
    $scope.init = function () {
        $scope.parsedVotes = [];
        $scope.scores = [];
        $scope.result = [];
        $scope.candidates = [];
        $scope.candidatesSet = [];
        $scope.percentages = [];
        $scope.done = false;
        $.smoothScroll({
            scrollTarget: '#data'
        });
    }
    $scope.init();
    $scope.labelForID = function (id) {
        for (var i = 0; i < $scope.candidates.length; i++) {
            var candA = $scope.candidates[i];
            if (candA.id === id) return candA.label;
        }
    }
    $scope.changeLanguage = function (key) {
        $translate.use(key);
    };
    $scope.parseVotes = function () {
        $scope.message = "We take the textual votes and add them"
        $scope.init();
        var lines = $scope.votes.split("\n");
        var cand = [];
        for (var i = 0; i < lines.length; i++) {
            var withoutComment = lines[i].split("#")[0];
            var numberAndVote = withoutComment.split(":");
            if (numberAndVote.length != 2) continue;
            var number = Number(numberAndVote[0]);
            var vote = numberAndVote[1];
            var candidates = vote.split(">");
            var newVote = {
                number: number
                , vote: []
            };
            for (var c = 0; c < candidates.length; c++) {
                var candidate = candidates[c].trim();
                // if it contains =
                if (candidate.indexOf('=') > -1) {
                    var exaequo = candidate.split('=');
                    var set = [];
                    for (var ex = 0; ex < exaequo.length; ex++) {
                        var exOne = exaequo[ex];
                        exOne = exOne.trim();
                        set.push(exOne);
                        cand.push(exOne);
                    }
                    newVote.vote.push(set);
                } else {
                    cand.push(candidate);
                    newVote.vote.push([candidate]);
                }
            }
            newVote.activeChoice = [newVote.vote[0][0]];
            $scope.parsedVotes.push(newVote);
        }
        cand.sort();
        console.log(cand);
        $scope.candidatesSet = Array.from(new Set(cand));
        var id = 1;
        for (var i = 0; i < $scope.candidatesSet.length; i++) {
            var candA = $scope.candidatesSet[i];
            var node = {
                id: (i + 1)
                , label: candA
                , pct: 10
                , color: $scope.colors[i]
            };
            $scope.candidates.push(node);
        }
        console.log($scope.candidatesSet);
        $.smoothScroll({
            scrollTarget: '#votes'
        });
        //$anchorScroll('votes');
    };

    $scope.isFirstActive = function (vote, candidat) {
        if (!$scope.isActive(candidat)) {
            return false;
        }
        for (var rank = 0; rank < vote.length; rank++) {
            var set = vote[rank];
            if (set.indexOf(candidat) > -1) return true;
            for (var s = 0; s <  set.length; s++) {
                var c = set[s];
                if ($scope.isActive(c)) return false;
            }
        }
        return true;
    }

    $scope.indexOf = function (vote, candidat) {
        for (var rank = 0; rank < vote.length; rank++) {
            var set = vote[rank];
            if (set.indexOf(candidat) > -1) return rank;
        }
        return -1;
    }

    $scope.computePercentages = function () {
        $scope.done = false;
        $scope.percentages = [];
        for (var c = 0; c < $scope.candidates.length; c++) {
            var candidate = $scope.candidates[c];
            var count = 0;
            for (var v = 0; v < $scope.parsedVotes.length; v++) {
                var vote = $scope.parsedVotes[v];
                if ($scope.indexOf(vote.vote, candidate.label) == 0) {
                    count += vote.number;
                }
            }
            var pct = count * 100 / $scope.totalVoters();
            var percentage = {
                label: candidate.label
                , color: candidate.color
                , count: count
                , total: count
                , pct: pct
                , totalpct: pct
                , recovered: []
                , active: true
            };
            if (percentage.totalpct > 50) {
                //alert(percentage.label + " wins");
                $scope.done = true;
            }
            $scope.percentages.push(percentage);
        }
        $scope.percentages.sort(
            function (p1, p2) {
                return p2.total - p1.total;
            }
        );
        $.smoothScroll({
            scrollTarget: '#result'
        });
    }

    $scope.activeChoicesFor = function(vote){
        var actives = [];
        for (var c = 0; c < $scope.candidates.length; c++) {
            var candidate = $scope.candidates[c];
            if ($scope.isFirstActive(vote.vote, candidate.label)) {
                actives.push(candidate.label);
            }
        }
        return actives;
    }

    $scope.findLoser = function () {
        var min = $scope.totalVoters();
        var loser;
        for (var p = 0; p < $scope.percentages.length; p++) {
            var percentage = $scope.percentages[p];
            if (percentage.active && percentage.totalpct < min) {
                loser = percentage;
                min = percentage.totalpct;
            }
        }
        console.log("Loser " + loser.label);
        loser.active = false;
        $scope.result.unshift([loser.label]);
        // got to compute how other recover some votes
        for (var p = 0; p < $scope.percentages.length; p++) {
            var percentage = $scope.percentages[p];
            var count = 0;
            for (var v = 0; v < $scope.parsedVotes.length; v++) {
                var vote = $scope.parsedVotes[v];
                vote.activeChoice = $scope.activeChoicesFor(vote);
                if ($scope.isFirstActive(vote.vote, percentage.label)) {
                    count += vote.number;
                }
            }
            if (count > percentage.total) {
                var pct = 100 * (count - percentage.total) / $scope.totalVoters();
                var gain = count - percentage.total;
                console.log(percentage.label + " wins " + (count - percentage.total));
                percentage.recovered.push({
                    color: loser.color
                    , pct: pct
                    , count: gain
                });
                percentage.total = count;
                percentage.totalpct = 100 * (count) / $scope.totalVoters();
                if (percentage.totalpct > 50) {
                    //alert(percentage.label + " wins");
                    $scope.done = true;
                }
            }
        }
        $scope.percentages.sort(
            function (p1, p2) {
                return p2.total - p1.total;
            }
        );
    }

    $scope.colorFor = function (label) {
        for (var c = 0; c < $scope.candidates.length; c++) {
            var candidate = $scope.candidates[c];
            if (candidate.label == label) return candidate.color;
        }
        return 'black';
    }
    $scope.isActive = function (label) {
        for (var p = 0; p < $scope.percentages.length; p++) {
            var percentage = $scope.percentages[p];
            if (label == percentage.label) {
                return percentage.active;
            }
        }
        return true;
    }
    $scope.result = [];
    // remove a source from the green graph and add it to the result (part of the topo sort)
    $scope.totalVoters = function () {
        var n = 0;
        for (var v = 0; v < $scope.parsedVotes.length; v++) {
            n += $scope.parsedVotes[v].number;
        }
        return n;
    }
});